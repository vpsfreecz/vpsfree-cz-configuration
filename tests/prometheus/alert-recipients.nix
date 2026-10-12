{
  pkgs,
  machines,
  confctl,
}:
let
  inherit (pkgs) lib;
  confLib = import (confctl + "/nix/lib") {
    confDir = ../..;
    coreLib = lib;
    corePkgs = pkgs;
  };

  # Exercise the public metadata option, including its type and normalization.
  recipients =
    value: labels:
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
          config.cluster.fixture = {
            host.fqdn = "fixture.int.vpsfree.cz";
            monitoring = {
              inherit labels;
              alertRecipients = value;
            };
          };
        }
      ];
      specialArgs = { inherit confLib; };
    }).config.cluster.fixture.monitoring.alertRecipients;
  succeeds = value: (builtins.tryEval (builtins.deepSeq value true)).success;

  aitherdev = machines."cz.vpsfree/machines/aitherdev".metaConfig;
  node = machines."cz.vpsfree/nodes/prg/node19".metaConfig;
  # Use the real inventory and pinned confctl carrier expansion. Netboot copies
  # share their ordinary node's FQDN and recipient policy.
  ordinaryMachines = lib.filterAttrs (_: machine: machine.carrier == null) machines;
  cluster = lib.mapAttrs (_: machine: machine.metaConfig) ordinaryMachines // {
    "cz.vpsfree/nodes/prg/node19" = node // {
      monitoring = node.monitoring // {
        alertRecipients = recipients [ "snajpa" "aither" "aither" ] { };
      };
    };
    mailOnly = aitherdev // {
      host = aitherdev.host // {
        fqdn = "mail-only.int.vpsfree.cz";
      };
      monitoring = aitherdev.monitoring // {
        alertRecipients = recipients [ "kerrycze" ] { };
      };
    };
    normal = aitherdev // {
      host = aitherdev.host // {
        fqdn = "normal.int.vpsfree.cz";
      };
      monitoring = aitherdev.monitoring // {
        alertRecipients = null;
      };
    };
  };
  alerter =
    (import ../../modules/clusterconf/alerter {
      inherit pkgs lib confLib;
      confData.monitoring = import ../../data/monitoring.nix;
      confMachine.services.alertmanager.port = 9093;
      config = {
        inherit cluster;
        clusterconf.alerter.enable = true;
      };
    }).config.content.services.prometheus.alertmanager.configuration;

  receiver =
    name: lib.findFirst (r: r.name == name) (throw "Missing receiver ${name}") alerter.receivers;
  hostRoute =
    fqdn:
    lib.findFirst (
      r: (r.match.fqdn or "") == fqdn
    ) (throw "Missing route ${fqdn}") alerter.route.routes;
  email = name: (builtins.head (receiver name).email_configs).to;
  receiverNames = map (r: r.name) alerter.receivers;
  nodeCopies = lib.filter (m: m.metaConfig.host.fqdn == node.host.fqdn) (
    confLib.getClusterMachines cluster
  );
  smsRoute =
    route: user:
    lib.findFirst (
      r:
      (r.match_re.severity or "") == "critical|fatal"
      && (builtins.head r.routes).receiver == "sms-${user}"
    ) (throw "Missing SMS ${user}") route.routes;
  checkSms =
    route: user:
    let
      sms = smsRoute route user;
      critical = builtins.elemAt sms.routes 0;
      fatal = builtins.elemAt sms.routes 1;
    in
    sms.continue
    && critical.match.severity == "critical"
    && fatal.match.severity == "fatal"
    && critical.active_time_intervals == [ "daytime-${user}" ]
    && builtins.all (r: r.active_time_intervals == [ "daytime-${user}" ]) critical.routes
    && !(fatal ? active_time_intervals)
    && builtins.all (r: !(r ? active_time_intervals)) fatal.routes
    && critical.group_wait == "10s"
    && fatal.group_wait == "10s"
    && critical.repeat_interval == "10m"
    && fatal.repeat_interval == "10m";

  # Run Alertmanager's own receiver selection with every transport made inert.
  routeFile = pkgs.writeText "alert-recipients.json" (
    builtins.toJSON {
      inherit (alerter) route time_intervals;
      receivers = map (r: { inherit (r) name; }) alerter.receivers;
    }
  );
in
assert recipients null { } == null;
assert
  recipients [ "snajpa" "aither" "aither" ] { } == [
    "aither"
    "snajpa"
  ];
assert recipients [ "aither" ] { fqdn = "fixture.int.vpsfree.cz"; } == [ "aither" ];
assert !(succeeds (recipients [ ] { }));
assert !(succeeds (recipients [ "unknown" ] { }));
assert !(succeeds (recipients [ "aither" ] { fqdn = "other.int.vpsfree.cz"; }));
assert aitherdev.monitoring.alertRecipients == [ "aither" ];
assert builtins.length nodeCopies > 1;
assert builtins.length (lib.filter (m: m.carrier == null) nodeCopies) == 1;
assert builtins.length receiverNames == builtins.length (lib.unique receiverNames);
assert
  builtins.length (lib.filter (name: name == "machine-mail-node19.prg.vpsfree.cz") receiverNames)
  == 1;
assert
  builtins.length (
    lib.filter (r: (r.match.fqdn or "") == "node19.prg.vpsfree.cz") alerter.route.routes
  ) == 1;
assert
  builtins.length (
    lib.filter (r: (r.match.fqdn or "") == "node19-mgmt.prg.vpsfree.cz") alerter.route.routes
  ) == 1;
assert
  builtins.length (
    lib.filter (r: (r.match.node_fqdn or "") == "node19.prg.vpsfree.cz") alerter.route.routes
  ) == 1;
assert email "team-mail" == "aither@havefun.cz,snajpa@snajpa.net,monitoring@kerrycze.net";
assert email "machine-mail-aitherdev.int.vpsfree.cz" == "aither@havefun.cz";
assert email "machine-mail-node19.prg.vpsfree.cz" == "aither@havefun.cz,snajpa@snajpa.net";
assert email "machine-mail-mail-only.int.vpsfree.cz" == "monitoring@kerrycze.net";
assert builtins.all (
  r: builtins.all (c: c.send_resolved) (r.email_configs or [ ])
) alerter.receivers;
assert checkSms (hostRoute "aitherdev.int.vpsfree.cz") "aither";
assert checkSms (hostRoute "node19.prg.vpsfree.cz") "aither";
assert checkSms (hostRoute "node19.prg.vpsfree.cz") "snajpa";
assert builtins.all (r: !((r.match or { }) ? fqdn) || !r.continue) alerter.route.routes;
pkgs.runCommand "alert-recipients" { nativeBuildInputs = [ pkgs.prometheus-alertmanager ]; } ''
  amtool check-config ${routeFile}
  export ALERTMANAGER_CONFIG=${routeFile}
  bash ${./alert-recipients-routing.sh}
  touch $out
''
