{ pkgs, lib, config, ... }:
{
  imports = [
    ../../../env.nix
  ];

  system.monitoring.enable = true;

  networking = {
    firewall.allowedTCPPorts = [
      3000  # grafana
    ];

    firewall.extraCommands = ''
      # Allow access to prometheus from proxy.prg
      iptables -A nixos-fw -p tcp --dport 9090 -s 37.205.14.61 -j nixos-fw-accept
    '';
  };

  services = {
    prometheus2 = {
      enable = true;
      extraFlags = [
        "--storage.tsdb.retention.time 365d"
        "--storage.tsdb.retention.size 200GB"
      ];
      webExternalUrl = "https://mon.prg.vpsfree.cz/";
      scrapeConfigs = [
        {
          job_name = "mon";
          scrape_interval = "60s";
          static_configs = [
            {
              targets = [
                "localhost:9090"
              ];
              labels = {
                alias = "mon.int.prg.vpsfree.cz";
              };
            }
            {
              targets = [
                "localhost:9100"
              ];
              labels = {
                alias = "mon.int.prg.vpsfree.cz";
              };
            }
          ];
        }
        {
          job_name = "pxe";
          scrape_interval = "60s";
          static_configs = [
            {
              targets = [
                "pxe.vpsfree.cz:9100"
              ];
              labels = {
                alias = "pxe.vpsfree.cz";
              };
            }
          ];
        }
        {
          job_name = "nodes";
          scrape_interval = "30s";
          static_configs = [
            # prg
            {
              targets = [
                "node2.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node2.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node3.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node3.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node4.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node4.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node5.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node5.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node6.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node6.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node7.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node7.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node8.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node8.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node9.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node9.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node10.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node10.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node11.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node11.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node12.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node12.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node13.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node13.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node14.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node14.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node15.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node15.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node17.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node17.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node18.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node18.prg";
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "backuper.prg.vpsfree.cz:9100"
                "backuper.prg.vpsfree.cz:9101"
              ];
              labels = {
                alias = "backuper.prg";
                location = "prg";
                role = "storage";
                os = "vpsadminos";
              };
            }
            {
              targets = [
                "nasbox.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "nasbox.prg";
                location = "prg";
                role = "storage";
                os = "openvz";
              };
            }
            # brq
            {
              targets = [
                "node1.brq.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node1.brq";
                location = "brq";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node2.brq.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node2.brq";
                location = "brq";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node3.brq.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node3.brq";
                location = "brq";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node4.brq.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node4.brq";
                location = "brq";
                role = "hypervisor";
                os = "openvz";
              };
            }
            # pgnd
            {
              targets = [
                "node1.pgnd.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node1.pgnd";
                location = "pgnd";
                role = "hypervisor";
                os = "openvz";
              };
            }
            # staging
            {
              targets = [
                "node1.stg.vpsfree.cz:9100"
                "node1.stg.vpsfree.cz:9101"
              ];
              labels = {
                alias = "node1.stg";
                location = "stg";
                role = "hypervisor";
                os = "vpsadminos";
              };
            }
            {
              targets = [
                "node2.stg.vpsfree.cz:9100"
                "node2.stg.vpsfree.cz:9101"
              ];
              labels = {
                alias = "node2.stg";
                location = "stg";
                role = "hypervisor";
                os = "vpsadminos";
              };
            }
          ];
        }
        {
          job_name = "infra";
          scrape_interval = "60s";
          static_configs = [
            {
              targets = [
                "build.vpsfree.cz:9100"
              ];
              labels = {
                alias = "build";
              };
            }
            {
              targets = [
                "www.vpsadminos.org:9100"
              ];
              labels = {
                alias = "www.vpsadminos.org";
              };
            }
            {
              targets = [
                "proxy.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "proxy.prg";
              };
            }
          ];
        }
        {
          job_name = "nodes-ping";
          scrape_interval = "15s";
          metrics_path = "/probe";
          params = {
            module = [ "icmp" ];
          };
          static_configs = [
            {
              targets = [
                "node2.prg.vpsfree.cz"
                "node3.prg.vpsfree.cz"
                "node4.prg.vpsfree.cz"
                "node5.prg.vpsfree.cz"
                "node6.prg.vpsfree.cz"
                "node7.prg.vpsfree.cz"
                "node8.prg.vpsfree.cz"
                "node9.prg.vpsfree.cz"
                "node10.prg.vpsfree.cz"
                "node11.prg.vpsfree.cz"
                "node12.prg.vpsfree.cz"
                "node13.prg.vpsfree.cz"
                "node14.prg.vpsfree.cz"
                "node15.prg.vpsfree.cz"
                "node17.prg.vpsfree.cz"
                "node18.prg.vpsfree.cz"
              ];
              labels = {
                location = "prg";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "nasbox.prg.vpsfree.cz"
              ];
              labels = {
                location = "prg";
                role = "storage";
                os = "openvz";
              };
            }
            {
              targets = [
                "backuper.prg.vpsfree.cz"
              ];
              labels = {
                location = "prg";
                role = "storage";
                os = "vpsadminos";
              };
            }
            {
              targets = [
                "node1.brq.vpsfree.cz"
                "node2.brq.vpsfree.cz"
                "node3.brq.vpsfree.cz"
                "node4.brq.vpsfree.cz"
              ];
              labels = {
                location = "brq";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node1.pgnd.vpsfree.cz"
              ];
              labels = {
                location = "pgnd";
                role = "hypervisor";
                os = "openvz";
              };
            }
            {
              targets = [
                "node1.stg.vpsfree.cz"
                "node2.stg.vpsfree.cz"
              ];
              labels = {
                location = "stg";
                role = "hypervisor";
                os = "vpsadminos";
              };
            }
          ];
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
      ];

      alertmanagerURL = [
        "172.16.4.11:9093"
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
              expr: up{job=~"infra|pxe"} == 0
              for: 10m
              labels:
                severity: critical
              annotations:
                summary: "Exporter down (instance {{ $labels.instance }})"
                description: "Prometheus exporter down\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: InfraHighCpuLoad
              expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",job=~"infra|pxe"}[5m])) * 100) > 80 and on(instance) time() - node_boot_time_seconds > 3600
              for: 10m
              labels:
                severity: warning
              annotations:
                summary: "High CPU load (instance {{ $labels.instance }})"
                description: "CPU load is > 80%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: InfraHighIoWait
              expr: (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",job=~"infra|pxe"}[5m])) * 100) > 30 and on(instance) time() - node_boot_time_seconds > 3600
              for: 10m
              labels:
                severity: warning
              annotations:
                summary: "High CPU iowait (instance {{ $labels.instance }})"
                description: "CPU iowait is > 30%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: InfraHighLoad
              expr: node_load5{job=~"infra|pxe"} > 300 and on(instance) time() - node_boot_time_seconds > 3600
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

    grafana = {
      enable = true;
      addr = "0.0.0.0";
      domain = "grafana.vpsfree.cz";
      rootUrl = "http://grafana.vpsfree.cz/";
    };
  };
}
