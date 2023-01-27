[
  {
    name = "outbound-net-ping";
    interval = "15s";
    rules = [
      {
        alert = "OutboundNetExporterDown";
        expr = ''up{job="outbound-net-ping"} == 0'';
        for = "1m";
        labels = {
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "Ping exporter is down (instance {{ $labels.instance }})";
          description = ''
            Unable to check outbound net connectivity

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "OutboundNetDown";
        expr = ''probe_success{job="outbound-net-ping"} == 0'';
        for = "60s";
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "Outbound net unreachable (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond to ping

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "SkNetHighLatency";
        expr = ''probe_icmp_duration_seconds{job="outbound-net-pid",address="37.9.169.172"} / 1000 > 80'';
        for = "60s";
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "Outbound net to SK has high latency (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} has high latency

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "SweNetHighLatency";
        expr = ''probe_icmp_duration_seconds{job="outbound-net-pid",address="93.188.1.250"} / 1000 > 300'';
        for = "60s";
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "Outbound net to SWE has high latency (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} has high latency

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
