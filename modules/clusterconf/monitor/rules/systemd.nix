[
  {
    name = "systemd";
    rules = [
      {
        alert = "SystemdUnitFailed";
        expr = ''node_systemd_unit_state{state="failed"} == 1'';
        labels = {
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "systemd unit failed (instance {{ $labels.instance }})";
          description = ''
            systemd unit is in a failed state

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "SystemdUnitActivatingTooLong";
        expr = ''node_systemd_unit_state{state="activating"} == 1'';
        for = "5m";
        labels = {
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "systemd unit is activating too long (instance {{ $labels.instance }})";
          description = ''
            systemd unit is activating for more than 5 minutes

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
