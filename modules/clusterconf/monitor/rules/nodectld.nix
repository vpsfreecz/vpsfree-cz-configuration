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
          (
            nodectld_vps_autostart_unsatisfied{role="hypervisor"} == 1
            and on(fqdn)
              nodectld_vps_autostart_check_success{role="hypervisor"} == 1
            and on(fqdn)
              time() - nodectld_vps_autostart_check_last_success_timestamp_seconds{role="hypervisor"} < 300
          )
          and on(fqdn)
            vpsfree_hypervisor_booting == 0
        '';
        for = "10m";
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "VPS {{ $labels.vps_id }} should be running on {{ $labels.fqdn }} in pool {{ $labels.pool }}";
          description = ''
            vpsAdmin has auto-start enabled for this VPS, but nodectld cannot
            find it in the running state.
          '';
        };
      }

      {
        alert = "VpsAutostartCheckFailed";
        expr = ''
          (
            nodectld_vps_autostart_check_success{role="hypervisor"} == 0
            or
              time() - nodectld_vps_autostart_check_last_success_timestamp_seconds{role="hypervisor"} > 300
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
            nodectld has not completed a recent comparison of the vpsAdmin
            auto-start settings with the containers in osctld.
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
