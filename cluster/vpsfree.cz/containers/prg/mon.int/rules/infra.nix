[
  {
    name = "infra";
    rules = [
      {
        alert = "InfraExporterDown";
        expr = ''up{job="infra"} == 0'';
        for = "10m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "Exporter down (instance {{ $labels.instance }})";
          description = ''
            Prometheus exporter down

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "InfraHighCpuLoad";
        expr = ''100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",job="infra"}[5m])) * 100) > 80 and on(instance) time() - node_boot_time_seconds > 3600'';
        for = "10m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High CPU load (instance {{ $labels.instance }})";
          description = ''
            CPU load is > 80%

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "InfraHighIoWait";
        expr = ''(avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",job="infra"}[5m])) * 100) > 30 and on(instance) time() - node_boot_time_seconds > 3600'';
        for = "10m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High CPU iowait (instance {{ $labels.instance }})";
          description = ''
            CPU iowait is > 30%

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "InfraHighLoad";
        expr = ''node_load5{job="infra"} > 300 and on(instance) time() - node_boot_time_seconds > 3600'';
        for = "10m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "Load average too high (instance {{ $labels.instance }})";
          description = ''
            5 minute load average is too high

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
