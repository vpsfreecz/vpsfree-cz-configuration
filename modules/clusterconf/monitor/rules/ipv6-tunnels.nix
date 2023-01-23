[
  {
    name = "ipv6-tunnels-ping";
    interval = "15s";
    rules = [
      {
        alert = "Ipv6TunnelExporterDown";
        expr = ''up{job="ipv6-tunnels-ping"} == 0'';
        for = "5m";
        labels = {
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "Ping exporter is down (instance {{ $labels.instance }})";
          description = ''
            Unable to check IPv6 tunnels availability

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "Ipv6TunnelIpDown";
        expr = ''probe_success{job="ipv6-tunnels-ping"} == 0'';
        for = "120s";
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "IPv6 tunnels IP is down (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond to ping

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
