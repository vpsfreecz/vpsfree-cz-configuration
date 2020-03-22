[
  {
    name = "dns-authoritatives";
    interval = "60s";
    rules = [
      {
        alert = "DnsExporterDown";
        expr = ''up{job="dns-authoritatives"} == 0'';
        for = "5m";
        labels = {
          severity = "critical";
          frequency = "hourly";
        };
        annotations = {
          summary = "DNS exporter is down (instance {{ $labels.instance }})";
          description = ''
            Unable to check authoritative DNS server availability

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "DnsAuthoritativeDown";
        expr = ''probe_success{job="dns-authoritatives"} == 0'';
        for = "2m";
        labels = {
          severity = "fatal";
          frequency = "2m";
        };
        annotations = {
          summary = "Authoritative DNS server is down (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not resolve domains

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
