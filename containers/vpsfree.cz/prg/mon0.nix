{ pkgs, lib, config, ... }:
{
  imports = [
    ../../../env.nix
    ../../../profiles/ct.nix
    ../../../modules/monitored.nix
  ];

  networking = {
    firewall.allowedTCPPorts = [
      3000  # grafana
      9090  # prometheus
    ];
  };

  services = {
    prometheus2 = {
      enable = true;
      extraFlags = [
        "--storage.tsdb.retention.time 365d"
        "--storage.tsdb.retention.size 200GB"
      ];
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
                alias = "mon0.prg.vpsfree.cz";
              };
            }
            {
              targets = [
                "localhost:9100"
              ];
              labels = {
                alias = "mon0.prg.vpsfree.cz";
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
            {
              targets = [
                "backuper.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "backuper.prg";
                location = "prg";
                role = "storage";
              };
            }
            {
              targets = [
                "node1.stg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node1.stg";
                location = "stg";
                role = "hypervisor";
              };
            }
            {
              targets = [
                "node2.stg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node2.stg";
                location = "stg";
                role = "hypervisor";
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
              for: 1m
              labels:
                severity: critical
                frequency: 2m
              annotations:
                summary: "Exporter down (instance {{ $labels.instance }})"
                description: "Prometheus exporter down\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: HypervisorHighCpuLoad
              expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",role="hypervisor"}[5m])) * 100) > 80
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "High CPU load (instance {{ $labels.instance }})"
                description: "CPU load is > 80%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: HypervisorCritCpuLoad
              expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",role="hypervisor"}[5m])) * 100) > 90
              for: 5m
              labels:
                severity: critical
              annotations:
                summary: "Critical CPU load (instance {{ $labels.instance }})"
                description: "CPU load is > 90%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: HypervisorHighIoWait
              expr: (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 20
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "High CPU iowait (instance {{ $labels.instance }})"
                description: "CPU iowait is > 20%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: HypervisorCritIoWait
              expr: (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 40
              for: 5m
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
              expr: node_zfs_arc_c{role="hypervisor"} < (node_memory_MemTotal_bytes / 8)
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
              for: 5m
              labels:
                severity: critical
              annotations:
                summary: "ZFS arc_meta_used uses too much of arc_size (instance {{ $labels.instance }})"
                description: "ZFS arc_meta_used uses more than 90% of arc_size\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: NodeHighLoad
              expr: node_load5{job="nodes"} > 300
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "Load average too high (instance {{ $labels.instance }})"
                description: "5 minute load average is too high\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: NodeCritLoad
              expr: node_load5{job="nodes"} > 1000
              for: 2m
              labels:
                severity: critical
                frequency: hourly
              annotations:
                summary: "Load average critical (instance {{ $labels.instance }})"
                description: "5 minute load average is too high\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

          - name: infra
            rules:
            - alert: InfraExporterDown
              expr: up{job=~"infra|pxe"} == 0
              for: 3m
              labels:
                severity: critical
              annotations:
                summary: "Exporter down (instance {{ $labels.instance }})"
                description: "Prometheus exporter down\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: InfraHighCpuLoad
              expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",job=~"infra|pxe"}[5m])) * 100) > 80
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "High CPU load (instance {{ $labels.instance }})"
                description: "CPU load is > 80%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: InfraHighIoWait
              expr: (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",job=~"infra|pxe"}[5m])) * 100) > 30
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "High CPU iowait (instance {{ $labels.instance }})"
                description: "CPU iowait is > 30%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

            - alert: InfraHighLoad
              expr: node_load5{job=~"infra|pxe"} > 300
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "Load average too high (instance {{ $labels.instance }})"
                description: "5 minute load average is too high\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"
        ''
      ];
    };

    grafana = {
      enable = true;
      addr = "0.0.0.0";
      domain = "grafana.vpsfree.cz";
      rootUrl = "http://grafana.vpsfree.cz/";
    };
  };
}
