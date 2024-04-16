[
  {
    name = "ipmi";
    rules = [
      {
        alert = "IpmiExporterDown";
        expr = ''up{job="nodes-ipmi"} == 0'';
        for = "10m";
        labels = {
          severity = "critical";
          frequency = "1h";
        };
        annotations = {
          summary = "IPMI down (instance {{ $labels.instance }})";
          description = ''
            IPMI exporter down

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "PowerSupplyDown";
        expr = ''ipmi_sensor_state{exported_type="Power Supply"} != 0'';
        labels = {
          severity = "fatal";
          frequency = "10m";
        };
        annotations = {
          summary = "Power supply down (instance {{ $labels.instance }})";
          description = ''
            Power supply down

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "FanWarning";
        expr = ''ipmi_fan_speed_state != 0'';
        labels = {
          severity = "warning";
          frequency = "6h";
        };
        annotations = {
          summary = "Fan warning reported (instance {{ $labels.instance }})";
          description = ''
            Fan warning reported

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
