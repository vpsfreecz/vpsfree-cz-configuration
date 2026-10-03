{ pkgs, machines }:

let
  inherit (pkgs) lib;
  meet = import ../../data/meet.nix;
  classifications = {
    "cz.vpsfree/containers/int.kb" = "vps";
    "cz.vpsfree/containers/prg/int.mon1" = "vps";
    "cz.vpsfree/containers/prg/int.mon2" = "vps";
    "cz.vpsfree/machines/aitherdev" = "vm";
    "cz.vpsfree/machines/em1" = "vm";
    "cz.vpsfree/machines/build" = "vm";
    "cz.vpsfree/machines/prg/apu" = "physical";
    "cz.vpsfree/nodes/prg/node19" = "physical";
    "cz.vpsfree/nodes/prg/backuper2" = "physical";
  };

  # Real evaluated metadata, with conflicting custom labels on every constructor.
  cluster = lib.mapAttrs (
    name: _:
    let
      meta = machines.${name}.metaConfig;
    in
    meta
    // {
      monitoring = meta.monitoring // {
        labels = {
          machine_type = "conflicting-custom-type";
          fixture_label = "kept";
        };
      };
      services =
        meta.services
        // lib.optionalAttrs (meta.node != null) {
          zfs-exporter = {
            port = 9134;
            address = meta.addresses.primary.address;
            monitor = null;
          };
          ipmi-exporter = {
            port = 9290;
            address = meta.addresses.primary.address;
            monitor = null;
          };
        };
    }
  ) classifications;

  # The fixtures expose only inventory lookup; production modules generate labels.
  confLib = {
    getClusterMachines =
      c:
      lib.mapAttrsToList (name: metaConfig: {
        inherit name metaConfig;
        carrier = null;
      }) c;
    findMetaConfig = { cluster, name }: cluster.${name};
  };

  monitorJobs =
    monitorName:
    (import ../../modules/clusterconf/monitor {
      inherit pkgs lib confLib;
      confData = { inherit meet; };
      confMachine = cluster.${monitorName};
      config = {
        inherit cluster;
        clusterconf.monitor = {
          enable = true;
          monitorMachines = builtins.attrNames cluster;
        };
      };
    }).config.content.services.prometheus.scrapeConfigs;

  getJob = jobs: name: lib.findFirst (job: job.job_name == name) (throw "Missing job ${name}") jobs;
  getTarget =
    job: meta:
    lib.findFirst (
      target: target.labels.fqdn == meta.host.fqdn
    ) (throw "Missing target ${meta.host.fqdn}") job.static_configs;
  endpoint =
    meta: port:
    "${
      if meta.monitoring.target == null then meta.host.fqdn else meta.monitoring.target
    }:${toString port}";
  alias =
    meta:
    "${meta.host.name}${lib.optionalString (meta.host.location != null) ".${meta.host.location}"}";
  identity = meta: {
    alias = alias meta;
    fqdn = meta.host.fqdn;
    machine_type = meta.machineType;
    fixture_label = "kept";
  };
  hostLabels =
    meta:
    identity meta
    // {
      domain = meta.host.domain;
      location = if meta.host.location == null then "global" else meta.host.location;
      os = meta.spin;
    };
  nodeLabels =
    meta:
    hostLabels meta
    // {
      type = "node";
      role = meta.node.role;
      storage_type = meta.node.storageType;
    };
  exporterTargets =
    meta:
    [ (endpoint meta meta.services.node-exporter.port) ]
    ++ lib.optional (meta.services ? osctl-exporter) (endpoint meta meta.services.osctl-exporter.port)
    ++ lib.optional (meta.services ? ebpf-exporter) (endpoint meta meta.services.ebpf-exporter.port)
    ++ lib.optional (meta.node != null && meta.services ? ksvcmon-exporter) (
      endpoint meta meta.services.ksvcmon-exporter.port
    );

  checkMeetJob =
    jobs:
    let
      groups = (getJob jobs "meet-jvbs").static_configs;
      groupCount = lib.foldl' (
        count: project: count + builtins.length (builtins.attrNames project.videoBridges)
      ) 0 (builtins.attrValues meet);
    in
    builtins.length groups == groupCount
    && builtins.all (
      project:
      let
        data = meet.${project};
      in
      builtins.all (
        name:
        (lib.findFirst (
          group: group.labels.alias == "meet-${name}" && group.labels.project == project
        ) { } groups) == {
          targets = map (port: "${data.videoBridges.${name}}:${toString port}") data.jvbExporterPorts;
          labels = {
            alias = "meet-${name}";
            type = "meet-jvb";
            inherit project;
            machine_type = "vps";
          };
        }
      ) (builtins.attrNames data.videoBridges)
    ) (builtins.attrNames meet)
    && builtins.elem {
      targets = [
        "37.205.14.138:9100"
        "37.205.14.138:9700"
      ];
      labels = {
        alias = "meet-jvb1";
        type = "meet-jvb";
        project = "vpsfree";
        machine_type = "vps";
      };
    } groups;

  checkMonitor =
    monitorName:
    let
      jobs = monitorJobs monitorName;
      mon = getJob jobs "mon";
      local = cluster.${monitorName};
      infra = getJob jobs "infra";
      nodes = getJob jobs "nodes";
      nodeMetas = lib.filter (meta: meta.node != null) (builtins.attrValues cluster);
      infraMetas = lib.filter (meta: meta.node == null && !meta.monitoring.isMonitor) (
        builtins.attrValues cluster
      );
      checkNodeJob =
        jobName: role: port:
        let
          job = getJob jobs jobName;
          metas = lib.filter (meta: role == null || meta.node.role == role) nodeMetas;
        in
        builtins.length job.static_configs == builtins.length metas
        && builtins.all (
          meta:
          getTarget job meta == {
            targets = [ (endpoint meta port) ];
            labels = nodeLabels meta;
          }
        ) metas;
    in
    builtins.length mon.static_configs == 2
    &&
      getTarget mon local == {
        targets = [
          "localhost:9090"
          "localhost:9100"
        ];
        labels = identity local;
      }
    &&
      builtins.all
        (
          meta:
          getTarget mon meta == {
            targets = [ (endpoint meta meta.services.node-exporter.port) ];
            labels = identity meta;
          }
        )
        (
          lib.filter (meta: meta.monitoring.isMonitor && meta.host.fqdn != local.host.fqdn) (
            builtins.attrValues cluster
          )
        )
    && builtins.length infra.static_configs == builtins.length infraMetas
    && builtins.all (
      meta:
      getTarget infra meta == {
        targets = exporterTargets meta;
        labels = hostLabels meta;
      }
    ) infraMetas
    && builtins.length nodes.static_configs == builtins.length nodeMetas
    && builtins.all (
      meta:
      getTarget nodes meta == {
        targets = exporterTargets meta;
        labels = nodeLabels meta;
      }
    ) nodeMetas
    && checkNodeJob "nodes-zfs-hypervisor" "hypervisor" 9134
    && checkNodeJob "nodes-zfs-storage" "storage" 9134
    && checkNodeJob "nodes-ipmi" null 9290
    && checkMeetJob jobs;

  metadataFixture =
    machineType:
    (lib.evalModules {
      modules = [
        ../../modules/cluster
        {
          options.cluster = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                freeformType = lib.types.attrs;
                options.spin = lib.mkOption {
                  type = lib.types.str;
                  default = "other";
                };
              }
            );
          };
          config.cluster.invalid = { inherit machineType; };
        }
      ];
      specialArgs.confLib = confLib;
    }).config.cluster.invalid.machineType;

  alerter =
    (import ../../modules/clusterconf/alerter {
      inherit pkgs lib confLib;
      confData = { };
      confMachine.services.alertmanager.port = 9093;
      config.clusterconf.alerter.enable = true;
    }).config.content.services.prometheus.alertmanager.configuration;
  routes = alerter.route.routes;
  mail = builtins.elemAt routes 0;
  telegram = builtins.elemAt routes 1;
  smsAither = builtins.elemAt routes 2;
  smsSnajpa = builtins.elemAt routes 3;
  none = builtins.elemAt routes 4;
  hourly =
    route:
    (lib.findFirst (r: (r.match.frequency or "") == "hourly") { } route.routes).repeat_interval == "1h";
  smsInterval =
    route: interval:
    let
      critical = builtins.head route.routes;
    in
    critical.receiver == "sms-${interval}"
    && critical.active_time_intervals == [ "daytime-${interval}" ]
    && hourly critical
    && builtins.all (r: r.active_time_intervals == [ "daytime-${interval}" ]) critical.routes;

  # Retain production routes/intervals; replace all transports with inert names.
  routeFile = pkgs.writeText "infra-monitoring-alertmanager.json" (
    builtins.toJSON {
      inherit (alerter) route time_intervals;
      receivers = map (receiver: { inherit (receiver) name; }) alerter.receivers;
    }
  );
  commonGroup = builtins.head (import ../../modules/clusterconf/monitor/rules/common.nix);
  ruleFile = pkgs.writeText "infra-monitoring-filesystem.json" (
    builtins.toJSON {
      groups = [
        (
          commonGroup
          // {
            rules = lib.filter (
              rule:
              builtins.elem (rule.alert or "") [
                "FilesystemLowFreeSpace"
                "FilesystemCritFreeSpace"
              ]
            ) commonGroup.rules;
          }
        )
      ];
    }
  );
  testFile = pkgs.replaceVars ./infra-monitoring-filesystem.yml { inherit ruleFile; };
in
assert builtins.all (name: machines.${name}.metaConfig.machineType == classifications.${name}) (
  builtins.attrNames classifications
);
assert metadataFixture "vm" == "vm";
assert !(builtins.tryEval (metadataFixture "invalid")).success;
assert checkMonitor "cz.vpsfree/containers/prg/int.mon1";
assert checkMonitor "cz.vpsfree/containers/prg/int.mon2";
assert builtins.length routes == 5;
assert
  none == {
    match.severity = "none";
    receiver = "blackhole";
    continue = false;
  };
assert mail.receiver == "team-mail" && mail.continue && hourly mail;
assert telegram.receiver == "team-telegram" && telegram.continue && hourly telegram;
assert smsAither.continue && smsInterval smsAither "aither";
assert smsSnajpa.continue && smsInterval smsSnajpa "snajpa";
assert
  alerter.time_intervals == [
    {
      name = "daytime-aither";
      time_intervals = [
        {
          times = [
            {
              start_time = "07:00";
              end_time = "22:00";
            }
          ];
          location = "Europe/Prague";
        }
      ];
    }
    {
      name = "daytime-snajpa";
      time_intervals = [
        {
          times = [
            {
              start_time = "09:00";
              end_time = "23:00";
            }
          ];
          location = "Europe/Prague";
        }
      ];
    }
  ];
pkgs.runCommand "infra-monitoring-config"
  {
    nativeBuildInputs = [
      pkgs.prometheus-alertmanager
      pkgs.prometheus.cli
    ];
  }
  ''
    amtool check-config ${routeFile}
    export ALERTMANAGER_CONFIG=${routeFile}
    bash ${./infra-monitoring-routing.sh}
    promtool check rules ${ruleFile}
    promtool test rules ${testFile}
    touch $out
  ''
