{ pkgs, lib, confLib, config, deploymentInfo, ... }:
with lib;
let
  alertsPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "vpsfree.cz";
    location = "prg";
    name = "alerts.int";
  };

  grafanaPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "vpsfree.cz";
    location = "prg";
    name = "grafana.int";
  };

  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "vpsfree.cz";
    location = "prg";
    name = "proxy";
  };

  promPort = deploymentInfo.config.services.prometheus.port;
  exporterPort = deploymentInfo.config.services.node-exporter.port;

  allDeployments = confLib.getClusterDeployments config.cluster;

  getAlias = d: "${d.name}${optionalString (!isNull d.location) ".${d.location}"}";
  ensureLocation = location: if location == null then "global" else location;

  scrapeConfigs = {
    monitorings =
      let
        deps = filter (d:
          d.config.monitoring.enable && d.config.monitoring.isMonitor && d.fqdn != deploymentInfo.fqdn
        ) allDeployments;
      in {
        exporterConfigs = [
          {
            targets = [
              "localhost:${toString promPort}"
              "localhost:${toString exporterPort}"
            ];
            labels = {
              alias = getAlias deploymentInfo;
              fqdn = deploymentInfo.fqdn;
            } // deploymentInfo.config.monitoring.labels;
          }
        ] ++ (flatten (map (d: {
          targets = [
            "${d.fqdn}:${toString d.services.prometheus.port}"
            "${d.fqdn}:${toString d.services.node-exporter.port}"
          ];
          labels = {
            alias = getAlias d;
            fqdn = d.fqdn;
          } // d.config.monitoring.labels;
        }) deps));

        pingConfigs = map (d: {
          targets = [ d.fqdn ];
          labels = {
            domain = d.domain;
            location = realLocation d.location;
            os = d.spin;
          };
        }) deps;
      };

    infra =
      let
        deps = filter (d:
          d.config.monitoring.enable && !d.config.monitoring.isMonitor && (d.type == "machine" || d.type == "container")
        ) allDeployments;
      in {
        exporterConfigs = map (d: {
          targets = [
            "${d.fqdn}:${toString d.config.services.node-exporter.port}"
          ] ++ (optional (hasAttr "osctl-exporter" d.config.services) "${d.fqdn}:${toString d.config.services.osctl-exporter.port}");
          labels = {
            alias = getAlias d;
            fqdn = d.fqdn;
            domain = d.domain;
            location = ensureLocation d.location;
            type = d.type;
            os = d.spin;
          } // d.config.monitoring.labels;
        }) deps;

        pingConfigs = map (d: {
          targets = [ d.fqdn ];
          labels = {
            domain = d.domain;
            location = ensureLocation d.location;
            os = d.spin;
          };
        }) deps;
      };

    nodes =
      let
        deps = filter (d:
          d.config.monitoring.enable && d.type == "node"
        ) allDeployments;
      in {
        exporterConfigs = map (d: {
          targets = [
            "${d.fqdn}:${toString d.config.services.node-exporter.port}"
          ] ++ (optional (hasAttr "osctl-exporter" d.config.services) "${d.fqdn}:${toString d.config.services.osctl-exporter.port}");
          labels = {
            alias = getAlias d;
            fqdn = d.fqdn;
            domain = d.domain;
            location = ensureLocation d.location;
            type = d.type;
            os = d.spin;
            role = d.role;
          } // d.config.monitoring.labels;
        }) deps;

        pingConfigs = map (d: {
          targets = [ d.fqdn ];
          labels = {
            domain = d.domain;
            location = ensureLocation d.location;
            role = d.role;
            os = d.spin;
          };
        }) deps;
      };
  };
in {
  imports = [
    ../../../../../environments/base.nix
  ];

  networking = {
    firewall.extraCommands = ''
      # Allow access to prometheus from proxy.prg
      iptables -A nixos-fw -p tcp --dport ${toString promPort} -s ${proxyPrg.addresses.primary} -j nixos-fw-accept

      # Allow access to prometheus from grafana.int.prg
      iptables -A nixos-fw -p tcp --dport ${toString promPort} -s ${grafanaPrg.addresses.primary} -j nixos-fw-accept
    '';
  };

  services = {
    prometheus2 = {
      enable = true;
      extraFlags = [
        "--storage.tsdb.retention.time 365d"
        "--storage.tsdb.retention.size 200GB"
      ];
      listenAddress = "0.0.0.0:${toString promPort}";
      webExternalUrl = "https://mon.prg.vpsfree.cz/";
      scrapeConfigs = [
        {
          job_name = "mon";
          scrape_interval = "60s";
          static_configs = scrapeConfigs.monitorings.exporterConfigs;
        }
      ] ++ (optional (scrapeConfigs.monitorings.pingConfigs != [])
        {
          job_name = "mon-ping";
          scrape_interval = "15s";
          metrics_path = "/probe";
          params = {
            module = [ "icmp" ];
          };
          static_configs = scrapeConfigs.monitorings.pingConfigs;
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:9115";
            }
          ];
        }
      ) ++ [
        {
          job_name = "nodes";
          scrape_interval = "30s";
          static_configs = scrapeConfigs.nodes.exporterConfigs;
        }
      ] ++ (optional (scrapeConfigs.nodes.pingConfigs != [])
        {
          job_name = "nodes-ping";
          scrape_interval = "15s";
          metrics_path = "/probe";
          params = {
            module = [ "icmp" ];
          };
          static_configs = scrapeConfigs.nodes.pingConfigs;
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:9115";
            }
          ];
        }
      ) ++ [
        {
          job_name = "infra";
          scrape_interval = "60s";
          static_configs = scrapeConfigs.infra.exporterConfigs;
        }
      ] ++ (optional (scrapeConfigs.infra.pingConfigs != [])
        {
          job_name = "infra-ping";
          scrape_interval = "15s";
          metrics_path = "/probe";
          params = {
            module = [ "icmp" ];
          };
          static_configs = scrapeConfigs.infra.pingConfigs;
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:9115";
            }
          ];
        }
      );

      alertmanagerURL = [
        "${alertsPrg.services.alertmanager.address}:${toString alertsPrg.services.alertmanager.port}"
      ];

      rules = [
        ''
          groups:
          - name: common
            rules:
            - alert: ZpoolListFailed
              expr: zpool_list_success != 0
              for: 5m
              labels:
                severity: critical
              annotations:
                summary: "zpool list failed (instance {{ $labels.instance }})"
                description: "An error occurred while running zpool list\n  LABELS: {{ $labels }}"

            - alert: ZpoolListParseError
              expr: zpool_list_parse_success != 0
              labels:
                severity: warning
              annotations:
                summary: "Unexpected zpool list output (instance {{ $labels.instance }})"
                description: "An error occurred while parsing output of zpool list\n  LABELS: {{ $labels }}"

            - alert: DegradedZpool
              expr: zpool_list_healt != 0
              labels:
                severity: critical
                frequency: daily
              annotations:
                summary: "Zpool is degraded (instance {{ $labels.instance }})"
                description: "One or more devices have failed\n  LABELS: {{ $labels }}"

            - alert: ZpoolLowFreeSpace
              expr: zpool_list_capacity >= 80
              for: 1h
              labels:
                severity: warning
              annotations:
                summary: "Not enough free space (instance {{ $labels.instance }})"
                description: "Zpool uses more than 80% of available space\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: ZpoolCritFreeSpace
              expr: zpool_list_capacity >= 90
              for: 15m
              labels:
                severity: critical
                frequency: daily
              annotations:
                summary: "Not enough free space (instance {{ $labels.instance }})"
                description: "Zpool uses more than 90% of available space\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

          - name: nodes
            interval: 20s
            rules:
            - alert: NodeExporterDown
              expr: up{job="nodes"} == 0
              for: 5m
              labels:
                severity: critical
                frequency: 2m
              annotations:
                summary: "Exporter down (instance {{ $labels.instance }})"
                description: "Prometheus exporter down\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: HypervisorHighCpuLoad
              expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",role="hypervisor"}[5m])) * 100) > 80 and on(instance) time() - node_boot_time_seconds > 3600
              for: 10m
              labels:
                severity: warning
              annotations:
                summary: "High CPU load (instance {{ $labels.instance }})"
                description: "CPU load is > 80%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: HypervisorCritCpuLoad
              expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",role="hypervisor"}[5m])) * 100) > 90 and on(instance) time() - node_boot_time_seconds > 3600
              for: 10m
              labels:
                severity: critical
              annotations:
                summary: "Critical CPU load (instance {{ $labels.instance }})"
                description: "CPU load is > 90%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: HypervisorHighIoWait
              expr: (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 20 and on(instance) time() - node_boot_time_seconds > 3600
              for: 10m
              labels:
                severity: warning
              annotations:
                summary: "High CPU iowait (instance {{ $labels.instance }})"
                description: "CPU iowait is > 20%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: HypervisorCritIoWait
              expr: (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 40 and on(instance) time() - node_boot_time_seconds > 3600
              for: 10m
              labels:
                severity: critical
              annotations:
                summary: "Critical CPU iowait (instance {{ $labels.instance }})"
                description: "CPU iowait is > 40%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: StorageHighCpuLoad
              expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",role="storage"}[5m])) * 100) > 80
              for: 15m
              labels:
                severity: warning
              annotations:
                summary: "High CPU load (instance {{ $labels.instance }})"
                description: "CPU load is > 80%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: StorageHighIoWait
              expr: (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="storage"}[5m])) * 100) > 30
              for: 15m
              labels:
                severity: warning
              annotations:
                summary: "High CPU iowait (instance {{ $labels.instance }})"
                description: "CPU iowait is > 30%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: HypervisorLowZfsArcC
              expr: node_zfs_arc_c{role="hypervisor"} < (node_memory_MemTotal_bytes / 8) and on(instance) (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 10
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "ZFS arc_c too low (instance {{ $labels.instance }})"
                description: "ZFS arc_c is too low (less than 1/8 of total memory)\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: HypervisorHighArcMetaUsed
              expr: node_zfs_arc_arc_meta_used{role="hypervisor"} / node_zfs_arc_size * 100 > 80 and on(instance) (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 10
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "ZFS arc_meta_used uses too much of arc_size (instance {{ $labels.instance }})"
                description: "ZFS arc_meta_used uses more than 80% of arc_size\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: HypervisorCritArcMetaUsed
              expr: node_zfs_arc_arc_meta_used{role="hypervisor"} / node_zfs_arc_size * 100 > 90 and on(instance) (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 20
              for: 10m
              labels:
                severity: critical
              annotations:
                summary: "ZFS arc_meta_used uses too much of arc_size (instance {{ $labels.instance }})"
                description: "ZFS arc_meta_used uses more than 90% of arc_size\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: NodeHighLoad
              expr: node_load5{job="nodes"} > 300 and on(instance) time() - node_boot_time_seconds > 3600
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "Load average too high (instance {{ $labels.instance }})"
                description: "5 minute load average is too high\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: NodeCritLoad
              expr: node_load5{job="nodes"} > 1000
              for: 5m
              labels:
                severity: critical
                frequency: hourly
              annotations:
                summary: "Load average critical (instance {{ $labels.instance }})"
                description: "5 minute load average is too high\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: NoOsctlPoolImported
              expr: osctl_pool_count{job="nodes",role="hypervisor",state="active"} == 0
              for: 15m
              labels:
                severity: critical
                frequency: 10m
              annotations:
                summary: "No osctl pool in use (instance {{ $labels.instance }})"
                description: "No osctl pool is imported into osctld\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

          - name: nodes-ping
            interval: 15s
            rules:
            - alert: PingExporterDown
              expr: up{job="nodes-ping"} == 0
              for: 5m
              labels:
                severity: critical
                frequency: hourly
              annotations:
                summary: "Ping exporter is down (instance {{ $labels.instance }})"
                description: "Unable to check node availability\n  LABELS: {{ $labels }}"

            - alert: NodeDown
              expr: probe_success{job="nodes-ping"} == 0
              for: 30s
              labels:
                severity: critical
                frequency: 2m
              annotations:
                summary: "Node is down (instance {{ $labels.instance }})"
                description: "{{ $labels.instance }} does not respond to ping\n  LABELS: {{ $labels }}"

            - alert: NodeHighPing
              expr: probe_duration_seconds{job="nodes-ping"} >= 1 and on(job, instance) probe_success == 1
              for: 1m
              labels:
                severity: warning
                frequency: hourly
              annotations:
                summary: "Node is slow to respond (instance {{ $labels.instance }})"
                description: "{{ $labels.instance }} takes more than a second to ping\n  LABELS: {{ $labels }}"

          - name: infra
            rules:
            - alert: InfraExporterDown
              expr: up{job="infra"} == 0
              for: 10m
              labels:
                severity: critical
              annotations:
                summary: "Exporter down (instance {{ $labels.instance }})"
                description: "Prometheus exporter down\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: InfraHighCpuLoad
              expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",job="infra"}[5m])) * 100) > 80 and on(instance) time() - node_boot_time_seconds > 3600
              for: 10m
              labels:
                severity: warning
              annotations:
                summary: "High CPU load (instance {{ $labels.instance }})"
                description: "CPU load is > 80%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: InfraHighIoWait
              expr: (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",job="infra"}[5m])) * 100) > 30 and on(instance) time() - node_boot_time_seconds > 3600
              for: 10m
              labels:
                severity: warning
              annotations:
                summary: "High CPU iowait (instance {{ $labels.instance }})"
                description: "CPU iowait is > 30%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: InfraHighLoad
              expr: node_load5{job="infra"} > 300 and on(instance) time() - node_boot_time_seconds > 3600
              for: 10m
              labels:
                severity: warning
              annotations:
                summary: "Load average too high (instance {{ $labels.instance }})"
                description: "5 minute load average is too high\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"
        ''
      ];
    };

    prometheus.exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      configFile = pkgs.writeText "blackbox.yml" ''
        modules:
          icmp:
            prober: icmp
            timeout: 5s
            icmp:
              preferred_ip_protocol: "ip4"
      '';
    };
  };
}
