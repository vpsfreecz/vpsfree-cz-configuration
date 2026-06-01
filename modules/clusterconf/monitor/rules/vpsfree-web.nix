[
  {
    name = "vpsfree-web";
    interval = "300s";
    rules = [
      {
        alert = "VpsFreeCzExporterDown";
        expr = ''up{job="http_vpsfree_cz"} == 0'';
        for = "10m";
        labels = {
          severity = "critical";
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
        alert = "VpsFreeOrgExporterDown";
        expr = ''up{job="http_vpsfree_org"} == 0'';
        for = "10m";
        labels = {
          severity = "critical";
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
        alert = "VpsFreeWebDown";
        expr = ''probe_success{type="vpsfree-web"} == 0'';
        for = "120s";
        labels = {
          severity = "critical";
          frequency = "5m";
        };
        annotations = {
          summary = "vpsFree web is down (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond over HTTP

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsfStatusDown";
        expr = ''probe_success{type="vpsf-status"} == 0'';
        for = "120s";
        labels = {
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "status.vpsf.cz is down (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond over HTTP

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsfStatusIndexRenderStale";
        expr = ''
          absent_over_time(vpsfstatus_index_last_render_timestamp_seconds{job="vpsf-status"}[5m])
            or time() - max_over_time(vpsfstatus_index_last_render_timestamp_seconds{job="vpsf-status"}[5m]) > 300
        '';
        labels = {
          severity = "critical";
          frequency = "1h";
        };
        annotations = {
          summary = "status.vpsf.cz index page rendering is stale";
          description = ''
            status.vpsf.cz has not completed an index page render in more than
            five minutes, or the render timestamp metric has been missing for
            five minutes.

            VALUE: {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
