[
  {
    name = "monitorings";
    interval = "60s";
    rules = [
      {
        alert = "MonitoringExporterDown";
        expr = ''up{job="mon"} == 0'';
        for = "2m";
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "Monitoring exporter is down (instance {{ $labels.instance }})";
          description = ''
            Unable to check monitoring server availability

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
