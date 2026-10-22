[
  {
    name = "nodectld";
    rules = [
      {
        alert = "NodectldPaused";
        expr = "nodectld_state_paused == 1";
        for = "30m";
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "nodectld is paused (instance {{ $labels.instance }})";
          description = ''
            nodectld is paused and not executing transactions

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsAutostartNotRunning";
        expr = ''
          nodectld_vps_boot_autostart_unsatisfied{role="hypervisor"} == 1
          and on(fqdn)
            nodectld_vps_boot_autostart_supported{role="hypervisor"} == 1
          and on(fqdn)
            nodectld_vps_boot_autostart_state{role="hypervisor",state="active"} == 1
          and on(fqdn)
            nodectld_vps_boot_autostart_check_success{role="hypervisor"} == 1
          and on(fqdn)
            time() - nodectld_vps_boot_autostart_check_last_success_timestamp_seconds{role="hypervisor"} < 300
          and on(fqdn)
            vpsfree_hypervisor_booting == 0
        '';
        for = "10m";
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "VPS {{ $labels.vps_id }} has an unmet auto-start expectation on {{ $labels.fqdn }} in pool {{ $labels.pool }}";
          description = ''
            osctld has not observed this VPS running since node boot. Its boot
            auto-start obligation remains pending.
          '';
        };
      }

      {
        alert = "VpsAutostartCheckFailed";
        expr = ''
          nodectld_vps_boot_autostart_supported{role="hypervisor"} == 1
          and on(fqdn)
          (
            nodectld_vps_boot_autostart_state{role="hypervisor",state="unavailable"} == 1
            or
            (
              nodectld_vps_boot_autostart_state{role="hypervisor",state="active"} == 1
              and on(fqdn)
              (
                nodectld_vps_boot_autostart_check_success{role="hypervisor"} == 0
                or
                  time() - nodectld_vps_boot_autostart_check_last_success_timestamp_seconds{role="hypervisor"} >= 300
              )
            )
          )
          and on(fqdn)
            vpsfree_hypervisor_booting == 0
        '';
        for = "10m";
        labels = {
          severity = "warning";
          frequency = "10m";
        };
        annotations = {
          summary = "VPS auto-start status check is failing on {{ $labels.fqdn }}";
          description = ''
            nodectld cannot provide a recent VPS boot auto-start check. Check the
            exported state and reason for missing boot state or an unavailable
            dependency.
          '';
        };
      }

      {
        alert = "VpsAutostartAwaitingReboot";
        expr = ''
          nodectld_vps_boot_autostart_supported{role="hypervisor"} == 1
          and on(fqdn)
            nodectld_vps_boot_autostart_state{role="hypervisor",state="awaiting_reboot"} == 1
        '';
        labels.severity = "none";
        annotations = {
          summary = "VPS boot auto-start tracking awaits reboot on {{ $labels.fqdn }}";
          description = ''
            This node was upgraded during the current boot. Boot auto-start
            tracking begins after its next reboot. A reboot is not required for
            ordinary VPS operations.
          '';
        };
      }

      {
        alert = "VpsStartStalled";
        expr = ''nodectld_command_seconds{handler="Vps::Start"} > 60*20'';
        labels = {
          severity = "fatal";
          frequency = "10m";
        };
        annotations = {
          summary = "VPS start has stalled (instance {{ $labels.instance }})";
          description = ''
            VPS takes more than 20 minutes to start

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsStopStalled";
        expr = ''nodectld_command_seconds{handler="Vps::Stop"} > 60*20'';
        labels = {
          severity = "fatal";
          frequency = "10m";
        };
        annotations = {
          summary = "VPS stop has stalled (instance {{ $labels.instance }})";
          description = ''
            VPS takes more than 20 minutes to stop, it is quite likely stuck

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsRestartStalled";
        expr = ''nodectld_command_seconds{handler="Vps::Restart"} > 60*20'';
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "VPS restart has stalled (instance {{ $labels.instance }})";
          description = ''
            VPS takes more than 20 minutes to restart, it is quite likely stuck

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
