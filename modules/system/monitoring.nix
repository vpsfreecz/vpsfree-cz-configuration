{
  lib,
  config,
  pkgs,
  confMachine,
  confLib,
  ...
}:
with lib;
let
  cfg = config.system.monitoring;

  allMachines = confLib.getClusterMachines config.cluster;

  monitorings = filter (d: d.metaConfig.monitoring.isMonitor) allMachines;

  textfileDir = "/run/metrics";

  smartmon = pkgs.writeScript "smartmon.sh-wrapper" ''
    ${pkgs.node-exporter-textfile-collector-scripts}/bin/smartmon.sh > ${textfileDir}/smartmon.prom.$$
    mv ${textfileDir}/smartmon.prom.$$ ${textfileDir}/smartmon.prom
  '';

  # Handle exporters defined in nixpkgs or vpsAdminOS, dependending on confMachine
  nixpkgsExporters = rec {
    # Exporters handled by this module
    known =
      [
        "ipmi"
        "node"
      ]
      ++ (optionals (confMachine.spin == "vpsadminos") [
        "ksvcmon"
        "osctl"
      ]);

    # Exporters declared in machine metadata
    declared = attrNames confMachine.services;

    # Exporters available in nixpkgs or vpsAdminOS
    # Non-exporter attributes and deprecated exporters are filtered out
    available = filter (
      exporter:
      !(elem exporter [
        "assertions"
        "warnings"
        "minio"
        "tor"
        "unifi-poller"
      ])
    ) (attrNames config.services.prometheus.exporters);

    # Exporters enabled in machine configuration
    enabled = filter (exporter: config.services.prometheus.exporters.${exporter}.enable) available;

    ruleList = map (
      exporter:
      concatMapStringsSep "\n" (
        m: mkExporterRules exporter config.services.prometheus.exporters.${exporter} m
      ) monitorings
    ) enabled;
  };

  mkExporterRules = exporter: exporterCfg: m: ''
    # Allow access to ${exporter}-exporter from ${m.metaConfig.host.fqdn}
    iptables -A nixos-fw -p tcp -m tcp -s ${m.metaConfig.addresses.primary.address} --dport ${toString exporterCfg.port} -j nixos-fw-accept
  '';
in
{
  options = {
    system.monitoring = {
      enable = mkOption {
        type = types.bool;
        description = "Monitor this system";
      };
    };
  };

  config = mkMerge [
    {
      system.monitoring.enable = mkDefault confMachine.monitoring.enable;
    }

    # Set ports of known exporters to ports from service definition list
    (mkIf cfg.enable {
      services.prometheus.exporters = listToAttrs (
        map (
          exporter:
          nameValuePair exporter {
            port = confMachine.services."${exporter}-exporter".port;
          }
        ) (with nixpkgsExporters; intersectLists known declared)
      );
    })

    # All machines
    (mkIf cfg.enable {
      networking.firewall.extraCommands = concatStringsSep "\n" nixpkgsExporters.ruleList;

      services.prometheus.exporters = {
        node.enable = true;
      };
    })

    # NixOS machines
    (mkIf (cfg.enable && confMachine.spin == "nixos" && !config.boot.isContainer) {
      services.prometheus.exporters.node = {
        extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
        enabledCollectors = [
          "hwmon"
          "interrupts"
          "ksmd"
          "logind"
          "mdadm"
          "processes"
          "systemd"
          "textfile"
          "vmstat"
        ];
      };
    })

    # NixOS containers
    (mkIf (cfg.enable && confMachine.spin == "nixos" && config.boot.isContainer) {
      services.prometheus.exporters.node = {
        extraFlags = [
          "--collector.disable-defaults"
          "--collector.filesystem"
          "--collector.loadavg"
          "--collector.logind"
          "--collector.meminfo"
          "--collector.os"
          "--collector.systemd"
          "--collector.textfile"
          "--collector.textfile.directory=${textfileDir}"
          "--collector.uname"
        ];
      };

      # The node_exporter module sets this only when systemd is in enabledCollectors.
      # Since we're configuring the collectors manually to reduce node_exporter's
      # footprint, the condition does not match and the collector does not have
      # access to systemd's dbus socket.
      systemd.services.prometheus-node-exporter.serviceConfig.RestrictAddressFamilies = [ "AF_UNIX" ];
    })

    # vpsAdminOS nodes
    (mkIf (cfg.enable && confMachine.spin == "vpsadminos") {
      services.prometheus.exporters = {
        ipmi.enable = true;

        ksvcmon.enable = false;

        node = {
          extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
          enabledCollectors = [
            "hwmon"
            "interrupts"
            "ksmd"
            "mdadm"
            "nfs"
            "processes"
            "runit"
            "textfile"
            "vmstat"
          ];
          disabledCollectors = [
            # Disabled for performance reasons, heavy netlink usage
            "arp"
          ];
        };

        osctl.enable = true;
      };

      services.cron.systemCronJobs = [
        "0 9 * * * root ${smartmon}"
      ];
    })
  ];
}
