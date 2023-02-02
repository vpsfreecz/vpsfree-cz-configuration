[
  {
    name = "common";
    rules = [
      {
        alert = "ZpoolListFailed";
        expr = "zpool_list_success != 1";
        for = "5m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "zpool list failed (instance {{ $labels.instance }})";
          description = ''
            An error occurred while running zpool list

            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "ZpoolListParseError";
        expr = "zpool_list_parse_success != 1";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "Unexpected zpool list output (instance {{ $labels.instance }})";
          description = ''
            An error occurred while parsing output of zpool list

            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "DegradedZpool";
        expr = "zpool_list_health != 1";
        labels = {
          severity = "critical";
          frequency = "daily";
        };
        annotations = {
          summary = "Zpool is degraded (instance {{ $labels.instance }})";
          description = ''
            One or more devices have failed

            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "ZpoolLowFreeSpace";
        expr = "zpool_list_capacity >= 75";
        for = "1h";
        labels = {
          alertclass = "zpoolcap";
          severity = "warning";
        };
        annotations = {
          summary = "Not enough free space (instance {{ $labels.instance }})";
          description = ''
            Zpool uses more than 75% of available space

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "ZpoolCritFreeSpace";
        expr = "zpool_list_capacity >= 80";
        for = "15m";
        labels = {
          alertclass = "zpoolcap";
          severity = "critical";
          frequency = "hourly";
        };
        annotations = {
          summary = "Not enough free space (instance {{ $labels.instance }})";
          description = ''
            Zpool uses more than 80% of available space

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "ZpoolFatalFreeSpace";
        expr = "zpool_list_capacity >= 90";
        for = "15m";
        labels = {
          alertclass = "zpoolcap";
          severity = "fatal";
          frequency = "hourly";
        };
        annotations = {
          summary = "Not enough free space (instance {{ $labels.instance }})";
          description = ''
            Zpool uses more than 90% of available space

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "ZpoolStatusFailed";
        expr = "zpool_status_success != 1";
        for = "5m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "zpool status failed (instance {{ $labels.instance }})";
          description = ''
            An error occurred while running zpool status

            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "ZpoolStatusParseError";
        expr = "zpool_status_parse_success != 1";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "Unexpected zpool status output (instance {{ $labels.instance }})";
          description = ''
            An error occurred while parsing output of zpool status

            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "ZpoolStatusVdevErrorsWarn";
        expr = ''zpool_status_vdev_read_errors{vdev_state="online"} > 0 or on(instance, vdev_name) zpool_status_vdev_write_errors{vdev_state="online"} > 0 or on(instance, vdev_name) zpool_status_vdev_checksum_errors{vdev_state="online"} > 0'';
        labels = {
          alertclass = "zpool_vdev_errors";
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "Vdev is exhibiting errors (instance {{ $labels.instance }})";
          description = ''
            Vdev is exhibiting read/write/checksum errors

            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "ZpoolStatusVdevErrorsCrit";
        expr = ''zpool_status_vdev_read_errors{vdev_state="online"} > 10 or on(instance, vdev_name) zpool_status_vdev_write_errors{vdev_state="online"} > 0 or on(instance, vdev_name) zpool_status_vdev_checksum_errors{vdev_state="online"} > 10'';
        labels = {
          alertclass = "zpool_vdev_errors";
          severity = "critical";
          frequency = "hourly";
        };
        annotations = {
          summary = "Vdev is exhibiting errors (instance {{ $labels.instance }})";
          description = ''
            Vdev is exhibiting read/write/checksum errors

            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "VdevLogErrorsWarn";
        expr = ''zfs_vdevlog_vdev_read_errors > 100 or on(instance, vdev_guid) zfs_vdevlog_vdev_write_errors > 0 or on(instance, vdev_guid) zfs_vdevlog_vdev_checksum_errors > 100'';
        labels = {
          alertclass = "vdevlog_errors";
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "Vdev is exhibiting longstanding errors (instance {{ $labels.instance }})";
          description = ''
            Vdev is exhibiting longstanding read/write/checksum errors

            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "VdevLogErrorsCrit";
        expr = ''zfs_vdevlog_vdev_read_errors > 100 or on(instance, vdev_guid) zfs_vdevlog_vdev_write_errors > 5 or on(instance, vdev_guid) zfs_vdevlog_vdev_checksum_errors > 100'';
        labels = {
          alertclass = "vdevlog_errors";
          severity = "critical";
          frequency = "hourly";
        };
        annotations = {
          summary = "Vdev is exhibiting longstanding errors (instance {{ $labels.instance }})";
          description = ''
            Vdev is exhibiting longstanding read/write/checksum errors

            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "FilesystemLowFreeSpace";
        expr = ''(node_filesystem_avail_bytes{mountpoint=~"^(/)|(/run)|(/nix/store)"} / node_filesystem_size_bytes) * 100 < 25'';
        for = "5m";
        labels = {
          alertclass = "fsavail";
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "Not enough free space (instance {{ $labels.instance }})";
          description = ''
            Filesystem uses more than 75% of available space

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "FilesystemCritFreeSpace";
        expr = ''(node_filesystem_avail_bytes{mountpoint=~"^(/)|(/run)|(/nix/store)"} / node_filesystem_size_bytes) * 100 <= 20'';
        for = "5m";
        labels = {
          alertclass = "fsavail";
          severity = "critical";
          frequency = "hourly";
        };
        annotations = {
          summary = "Not enough free space (instance {{ $labels.instance }})";
          description = ''
            Filesystem uses more than 80% of available space

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
      {
        alert = "OsctlHealthCheckError";
        expr = ''osctl_health_check_error_count > 0'';
        for = "15m";
        labels = {
          severity = "warning";
          frequency = "6h";
        };
        annotations = {
          summary = "osctl health check detected errors (instance {{ $labels.instance }})";
          description = ''
            osctl health check detected errors

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
