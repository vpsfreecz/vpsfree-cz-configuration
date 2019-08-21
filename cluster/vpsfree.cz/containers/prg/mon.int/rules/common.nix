[
  {
    name = "common";
    rules = [
      {
        alert = "ZpoolListFailed";
        expr = "zpool_list_success != 0";
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
        expr = "zpool_list_parse_success != 0";
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
        expr = "zpool_list_healt != 0";
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
        expr = "zpool_list_capacity >= 80";
        for = "1h";
        labels = {
          severity = "warning";
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
        alert = "ZpoolCritFreeSpace";
        expr = "zpool_list_capacity >= 90";
        for = "15m";
        labels = {
          severity = "critical";
          frequency = "daily";
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
        alert = "ZpoolFatalFreeSpace";
        expr = "zpool_list_capacity >= 95";
        for = "15m";
        labels = {
          severity = "fatal";
          frequency = "daily";
        };
        annotations = {
          summary = "Not enough free space (instance {{ $labels.instance }})";
          description = ''
            Zpool uses more than 95% of available space

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
