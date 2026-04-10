[
  {
    name = "vpsadmin-download";
    interval = "300s";
    rules = [
      {
        alert = "VpsAdminDownloadHealthchecksMissing";
        expr = ''absent(script_success{job="vpsadmin-download-healthchecks"}) == 1'';
        for = "15m";
        labels = {
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "Prometheus has no vpsAdmin download healthcheck targets";
          description = ''
            Prometheus has no targets discovered for vpsAdmin download
            healthchecks. Check /sd/download-pools discovery and the
            local script exporter probe job.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsAdminDownloadHealthcheckFailed";
        expr = ''script_success{job="vpsadmin-download-healthchecks"} == 0'';
        for = "15m";
        labels = {
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "Download healthcheck failed for pool {{ $labels.pool_id }} on {{ $labels.node_fqdn }}";
          description = ''
            Download healthcheck probe failed for pool {{ $labels.pool_name }}
            (ID {{ $labels.pool_id }}) on node {{ $labels.node_fqdn }}.

            URL: {{ $labels.download_url }}

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
