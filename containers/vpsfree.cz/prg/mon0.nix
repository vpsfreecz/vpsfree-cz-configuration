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
          scrape_interval = "60s";
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
          - name: main
            rules:
            - alert: ExporterDown
              expr: up == 0
              for: 3m
              labels:
                severity: warning
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

            - alert: HypervisorHighIoWait
              expr: (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 20
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "High CPU iowait (instance {{ $labels.instance }})"
                description: "CPU iowait is > 20%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

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

            - alert: LowZfsArcC
              expr: node_zfs_arc_c < (node_memory_MemTotal_bytes / 8)
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "ZFS arc_c too low (instance {{ $labels.instance }})"
                description: "ZFS arc_c is too low (less than 1/8 of total memory)\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"
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
