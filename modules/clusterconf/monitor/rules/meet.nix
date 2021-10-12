[
  {
    name = "meet-jvbs";
    rules = [
      {
        alert = "MeetJvbExporterDown";
        expr = ''up{job="meet-jvbs"} == 0'';
        for = "5m";
        labels = {
          severity = "warning";
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
    ];
  }

  {
    name = "meet-ping";
    interval = "15s";
    rules = [
      {
        alert = "MeetPingExporterDown";
        expr = ''up{job="meet-jvbs-ping"} == 0'';
        for = "5m";
        labels = {
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "Ping exporter is down (instance {{ $labels.instance }})";
          description = ''
            Unable to check JVB availability

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "MeetJvbDown";
        expr = ''probe_success{job="meet-jvbs-ping"} == 0'';
        for = "5m";
        labels = {
          severity = "warning";
          frequency = "5m";
        };
        annotations = {
          summary = "JVB is down (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond to ping

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }

  {
    name = "meet-web";
    interval = "60s";
    rules = [
      {
        alert = "MeetWebExporterDown";
        expr = ''up{job="meet-web"} == 0'';
        for = "5m";
        labels = {
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "Web exporter is down (instance {{ $labels.instance }})";
          description = ''
            Unable to check web availability

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "MeetWebDown";
        expr = ''probe_success{job="meet-web"} == 0'';
        for = "120s";
        labels = {
          severity = "warning";
          frequency = "5m";
        };
        annotations = {
          summary = "Meet web is down (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond over HTTP

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
