let
  escapePromRegex = str: builtins.replaceStrings [ "." ] [ ''\\.'' ] str;

  mkPromRegexAlternation = values: builtins.concatStringsSep "|" (map escapePromRegex values);

  dnsRecordsSlowStartUnit = "vpsadmin-api-prometheus-export-dns-records.service";
  vpsAdminOSImageRepoSlowStartUnit = "build-vpsadminos-container-image-repository-vpsadminos.service";

  ignoredSystemdSlowStartUnits = [
    "munin-cron.service"
    dnsRecordsSlowStartUnit
    vpsAdminOSImageRepoSlowStartUnit
  ];

  mkSystemdSlowStartAlert =
    {
      alert,
      expr,
      forDuration,
      descriptionDuration,
    }:
    {
      inherit alert expr;
      for = forDuration;
      labels = {
        severity = "warning";
        frequency = "15m";
      };
      annotations = {
        summary = "systemd unit is activating too long (instance {{ $labels.instance }})";
        description = ''
          systemd unit is activating for more than ${descriptionDuration}

          LABELS: {{ $labels }}
        '';
      };
    };
in
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

      (mkSystemdSlowStartAlert {
        alert = "SystemdSlowStart";
        expr = ''
          node_systemd_unit_state{
            state="activating",
            name!~"${mkPromRegexAlternation ignoredSystemdSlowStartUnits}"
          } == 1
        '';
        forDuration = "5m";
        descriptionDuration = "5 minutes";
      })

      (mkSystemdSlowStartAlert {
        alert = "DnsRecordsSlowStart";
        expr = ''
          node_systemd_unit_state{
            state="activating",
            name="${dnsRecordsSlowStartUnit}"
          } == 1
        '';
        forDuration = "15m";
        descriptionDuration = "15 minutes";
      })

      (mkSystemdSlowStartAlert {
        alert = "VpsAdminOSImageRepoSlowStart";
        expr = ''
          node_systemd_unit_state{
            state="activating",
            name="${vpsAdminOSImageRepoSlowStartUnit}"
          } == 1
        '';
        forDuration = "18h";
        descriptionDuration = "18 hours";
      })
    ];
  }
]
