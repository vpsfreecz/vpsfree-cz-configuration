[
  {
    name = "syslog";
    rules = [
      {
        alert = "SyslogExporterDown";
        expr = ''up{job="log"} == 0'';
        for = "10m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "Syslog-exporter down (instance {{ $labels.instance }})";
          description = ''
            Syslog-exporter down

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodectldCrashed";
        expr = ''syslog_nodectld_crash == 1'';
        labels = {
          severity = "warning";
          frequency = "1m";
        };
        annotations = {
          summary = "nodectld has crashed (instance {{ $labels.instance }})";
          description = ''
            nodectld has crashed

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodectldSegfault";
        expr = ''syslog_nodectld_segfault == 1'';
        labels = {
          severity = "warning";
          frequency = "1m";
        };
        annotations = {
          summary = "nodectld has segfaulted (instance {{ $labels.instance }})";
          description = ''
            nodectld has segfaulted

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodectldZfsRecvError";
        expr = ''syslog_nodectld_zfs_stream_receive_error == 1'';
        labels = {
          severity = "warning";
          frequency = "1m";
        };
        annotations = {
          summary = "zfs recv stream receive error (instance {{ $labels.instance }})";
          description = ''
            zfs recv run by nodectld failed to receive stream

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "OsctldInternalError";
        expr = ''syslog_osctld_internal_error == 1'';
        labels = {
          severity = "warning";
          frequency = "1m";
        };
        annotations = {
          summary = "osctld internal error occurred (instance {{ $labels.instance }})";
          description = ''
            An internal error has occurred in osctld

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "LxcStartFailed";
        expr = ''syslog_lxc_start_failed == 1'';
        labels = {
          severity = "critical";
          frequency = "1m";
        };
        annotations = {
          summary = "lxc-start has failed (instance {{ $labels.instance }})";
          description = ''
            lxc-start has failed to start a container.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "LxcStartNetnsLimit";
        expr = ''syslog_lxc_start_netns_limit == 1'';
        labels = {
          alertclass = "lxcstartfail";
          severity = "fatal";
          frequency = "2m";
        };
        annotations = {
          summary = "lxc-start has hit netns limit (instance {{ $labels.instance }})";
          description = ''
            lxc-start has failed to start a container due to network namespace
            limit being reached, see sysctl user.max_net_namespaces.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "KernelNullPointer";
        expr = ''syslog_kernel_bug{type="nullptr"} == 1'';
        labels = {
          severity = "fatal";
          frequency = "1m";
        };
        annotations = {
          summary = "Kernel NULL pointer dereference has occurred (instance {{ $labels.instance }})";
          description = ''
            Kernel NULL pointer dereference has occurred

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "KernelGeneralProtectionFault";
        expr = ''syslog_kernel_gpf == 1'';
        labels = {
          severity = "fatal";
          frequency = "1m";
        };
        annotations = {
          summary = "Kernel general protection fault has occurred (instance {{ $labels.instance }})";
          description = ''
            Kernel general protection fault has occurred

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "KernelEmergencyWarn";
        expr = ''syslog_kernel_emergency == 1'';
        labels = {
          severity = "warning";
          frequency = "1h";
        };
        annotations = {
          summary = "Kernel emergency message detected (instance {{ $labels.instance }})";
          description = ''
            Kernel emergency message has been detected

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NfConntrackTableFull";
        expr = ''syslog_kernel_nf_conntrack_table_full == 1'';
        labels = {
          severity = "warning";
          frequency = "2m";
        };
        annotations = {
          summary = "Kernel nf_conntrack table is full (instance {{ $labels.instance }})";
          description = ''
            Kernel nf_conntrack table is full and packets are being dropped

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "ZfsPanic";
        expr = ''syslog_zfs_panic == 1'';
        labels = {
          severity = "fatal";
          frequency = "1m";
        };
        annotations = {
          summary = "ZFS panic has occurred (instance {{ $labels.instance }})";
          description = ''
            ZFS panic has occurred

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "KernelOomHighRate";
        expr = ''rate(syslog_kernel_oom_count[10m]) >= 10'';
        labels = {
          severity = "warning";
          frequency = "5m";
        };
        annotations = {
          summary = "More than 10 OOMs per second (instance {{ $labels.instance }})";
          description = ''
            Kernel reports more than 10 OOMs per second

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "KernelOomCritRate";
        expr = ''rate(syslog_kernel_oom_count[10m]) >= 50'';
        labels = {
          severity = "critical";
          frequency = "5m";
        };
        annotations = {
          summary = "More than 50 OOMs per second (instance {{ $labels.instance }})";
          description = ''
            Kernel reports more than 50 OOMs per second

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "KernelOomFatalRate";
        expr = ''rate(syslog_kernel_oom_count[10m]) >= 100'';
        labels = {
          severity = "fatal";
          frequency = "5m";
        };
        annotations = {
          summary = "More than 100 OOMs per second (instance {{ $labels.instance }})";
          description = ''
            Kernel reports more than 100 OOMs per second

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
