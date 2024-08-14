{ lib }:
let
  chains = rec {
    backup = "TransactionChains::Dataset::Backup";
    fullDownload = "TransactionChains::Dataset::FullDownload";
    vpsStart = "TransactionChains::Vps::Start";
    vpsRestart = "TransactionChains::Vps::Restart";
    vpsStop = "TransactionChains::Vps::Stop";
    vpsMigrateOs = "TransactionChains::Vps::Migrate::OsToOs";
    specials = [
      backup fullDownload
      vpsStart vpsRestart vpsStop
      vpsMigrateOs
    ];
  };

  # Attr names from ../http.nix
  httpSites = {
    "api_vpsfree_cz" = "ApiVpsfreeCz";
    "console_vpsfree_cz" = "ConsoleVpsfreeCz";
    "vpsadmin_vpsfree_cz" = "VpsadminVpsfreeCz";
  };
in [
  {
    name = "vpsadmin";
    rules = [
      {
        alert = "VpsAdminApiNotActive";
        expr = ''node_systemd_unit_state{name="vpsadmin-api.service",state="active"} == 0'';
        for = "10m";
        labels = {
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "vpsadmin-api.service on {{ $labels.node_name }} is not active";
          description = ''
            vpsadmin-api.service on {{ $labels.node_name }} is not active

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsAdminWebuiNotActive";
        expr = ''node_systemd_unit_state{name="phpfpm-vpsadmin-webui.service",state="active"} == 0'';
        for = "10m";
        labels = {
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "phpfpm-vpsadmin-webui.service on {{ $labels.node_name }} is not active";
          description = ''
            phpfpm-vpsadmin-webui.service on {{ $labels.node_name }} is not active

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsAdminConsoleRouterNotActive";
        expr = ''node_systemd_unit_state{name="vpsadmin-console-router.service",state="active"} == 0'';
        for = "10m";
        labels = {
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "vpsadmin-console-router.service on {{ $labels.node_name }} is not active";
          description = ''
            vpsadmin-console-router.service on {{ $labels.node_name }} is not active

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeCtldUnresponsive";
        expr = ''vpsadmin_node_last_report_seconds{node_platform="vpsadminos"} >= 90'';
        labels = {
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "nodectld on {{ $labels.node_name }} is not responding";
          description = ''
            nodectld on {{ $labels.node_name }} is not responding

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "TransactionChainFatal";
        expr = ''vpsadmin_transaction_chain_fatal == 1'';
        labels = {
          severity = "warning";
          frequency = "1h";
        };
        annotations = {
          summary = "Transaction chain {{ $labels.chain_id }} is in state fatal";
          description = ''
            Transaction chain {{ $labels.chain_id }} ({{ $labels.chain_type }})
            is in state fatal and needs to be resolved.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsMigrationFatal";
        expr = ''vpsadmin_transaction_chain_fatal{chain_type="${chains.vpsMigrateOs}"} == 1'';
        labels = {
          severity = "fatal";
          frequency = "10m";
        };
        annotations = {
          summary = "Transaction chain {{ $labels.chain_id }} is in state fatal";
          description = ''
            Transaction chain {{ $labels.chain_id }} ({{ $labels.chain_type }})
            is in state fatal and needs to be resolved.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsStartDelayed";
        expr = ''vpsadmin_transaction_chain_queued_seconds{chain_type="${chains.vpsStart}"} >= 15*60'';
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "Transaction chain {{ $labels.chain_id }} takes too long to start a VPS";
          description = ''
            Transaction chain {{ $labels.chain_id }} ({{ $labels.chain_type }})
            is in state {{ $labels.chain_state }} for too long and is potentially
            stuck.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsRestartDelayed";
        expr = ''vpsadmin_transaction_chain_queued_seconds{chain_type="${chains.vpsRestart}"} >= 15*60'';
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "Transaction chain {{ $labels.chain_id }} takes too long to restart a VPS";
          description = ''
            Transaction chain {{ $labels.chain_id }} ({{ $labels.chain_type }})
            is in state {{ $labels.chain_state }} for too long and is potentially
            stuck.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsStopDelayed";
        expr = ''vpsadmin_transaction_chain_queued_seconds{chain_type="${chains.vpsStop}"} >= 15*60'';
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "Transaction chain {{ $labels.chain_id }} takes too long to stop a VPS";
          description = ''
            Transaction chain {{ $labels.chain_id }} ({{ $labels.chain_type }})
            is in state {{ $labels.chain_state }} for too long and is potentially
            stuck.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsMigrationDelayed";
        expr = ''vpsadmin_transaction_chain_queued_seconds{chain_type="${chains.vpsMigrateOs}"} >= 24*60*60'';
        labels = {
          severity = "warning";
          frequency = "10m";
        };
        annotations = {
          summary = "Transaction chain {{ $labels.chain_id }} takes too long to migrate a VPS";
          description = ''
            Transaction chain {{ $labels.chain_id }} ({{ $labels.chain_type }})
            is in state {{ $labels.chain_state }} for too long and is potentially
            stuck.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "DatasetBackupDelayed";
        expr = ''vpsadmin_transaction_chain_queued_seconds{chain_type="${chains.backup}"} >= 12*60*60'';
        labels = {
          severity = "warning";
          frequency = "1h";
        };
        annotations = {
          summary = "Transaction chain {{ $labels.chain_id }} takes too long";
          description = ''
            Transaction chain {{ $labels.chain_id }} ({{ $labels.chain_type }})
            is in state {{ $labels.chain_state }} for too long and is potentially
            stuck.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "BackupDownloadDelayed";
        expr = ''vpsadmin_transaction_chain_queued_seconds{chain_type="${chains.fullDownload}"} >= 12*60*60'';
        labels = {
          severity = "warning";
          frequency = "1h";
        };
        annotations = {
          summary = "Transaction chain {{ $labels.chain_id }} takes too long";
          description = ''
            Transaction chain {{ $labels.chain_id }} ({{ $labels.chain_type }})
            is in state {{ $labels.chain_state }} for too long and is potentially
            stuck.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "TransactionChainDelayed";
        expr = ''vpsadmin_transaction_chain_queued_seconds{chain_type!~"${lib.concatStringsSep "|" chains.specials}"} >= 3*60*60'';
        labels = {
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "Transaction chain {{ $labels.chain_id }} takes too long";
          description = ''
            Transaction chain {{ $labels.chain_id }} ({{ $labels.chain_type }})
            is in state {{ $labels.chain_state }} for too long and is potentially
            stuck.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "DatasetExpansionCountWarn";
        expr = ''vpsadmin_dataset_expansion_count > 3'';
        labels = {
          severity = "warning";
          frequency = "6h";
        };
        annotations = {
          summary = "VPS {{ $labels.vps_id }} on {{ $labels.vps_node }} expanded >3 times";
          description = ''
            Dataset {{ $labels.dataset_name }} in VPS {{ $labels.vps_id }} on {{ $labels.vps_node }}
            is expanded more than 3 times.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "DatasetExpansionCountCrit";
        expr = ''vpsadmin_dataset_expansion_count > 5'';
        labels = {
          severity = "critical";
          frequency = "6h";
        };
        annotations = {
          summary = "VPS {{ $labels.vps_id }} on {{ $labels.vps_node }} expanded >5 times";
          description = ''
            Dataset {{ $labels.dataset_name }} in VPS {{ $labels.vps_id }} on {{ $labels.vps_node }}
            is expanded more than 5 times.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "DatasetExpansionSpaceWarn";
        expr = ''vpsadmin_dataset_expansion_added_bytes > 100*1024*1024*1024'';
        labels = {
          severity = "warning";
          frequency = "6h";
        };
        annotations = {
          summary = "VPS {{ $labels.vps_id }} on {{ $labels.vps_node }} given >100G";
          description = ''
            Dataset {{ $labels.dataset_name }} in VPS {{ $labels.vps_id }} on {{ $labels.vps_node }}
            uses more than 100G of extra space.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "DatasetExpansionDeadlineWarn";
        expr = ''vpsadmin_dataset_expansion_over_refquota_seconds > vpsadmin_dataset_expansion_max_over_refquota_seconds'';
        labels = {
          severity = "warning";
          frequency = "12h";
        };
        annotations = {
          summary = "VPS {{ $labels.vps_id }} on {{ $labels.vps_node }} is expanded for too long";
          description = ''
            Dataset {{ $labels.dataset_name }} in VPS {{ $labels.vps_id }} on {{ $labels.vps_node }}
            has exceeded its deadline.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "ExportHostIpOwnerMismatch";
        expr = ''vpsadmin_export_host_ip_owner_mismatch == 1'';
        labels = {
          severity = "warning";
          frequency = "1h";
        };
        annotations = {
          summary = "Export {{ $labels.export_id }} of user {{ $labels.user_id }} has mismatching host IP owner";
          description = ''
            Export {{ $labels.export_id }} of user {{ $labels.user_id_id }} has mismatching
            host IP owner.

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "DnsZoneSerialMismatch";
        expr = ''count(count_values("serial", vpsadmin_dns_server_zone_serial) by (dns_zone)) by (dns_zone) > 1'';
        for = "10m";
        labels = {
          severity = "warning";
          frequency = "6h";
        };
        annotations = {
          summary = "Zone {{ $labels.dns_zone }} is out of sync";
          description = ''
            Zone {{ $labels.dns_zone }} is out of sync, servers are reporting different
            serial numbers.

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }

  {
    name = "vpsadmin-front";
    interval = "300s";
    rules = lib.flatten (lib.mapAttrsToList (name: camel: [
      {
        alert = "${camel}ExporterDown";
        expr = ''up{job="http_${name}"} == 0'';
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
        alert = "${camel}WebDown";
        expr = ''probe_success{job="http_${name}"} == 0'';
        for = "120s";
        labels = {
          severity = "critical";
          frequency = "5m";
        };
        annotations = {
          summary = "{{ $labels.instance }} web is down";
          description = ''
            {{ $labels.instance }} does not respond over HTTP

            LABELS: {{ $labels }}
          '';
        };
      }
    ]) httpSites);
  }
]
