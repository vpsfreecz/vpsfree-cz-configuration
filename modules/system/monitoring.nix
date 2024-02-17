{ lib, config, pkgs, confMachine, confLib, ... }:
with lib;
let
  cfg = config.system.monitoring;

  allMachines = confLib.getClusterMachines config.cluster;

  monitorings = filter (d: d.config.monitoring.isMonitor) allMachines;

  ipmiExporterPort = confMachine.services.ipmi-exporter.port;

  nodeExporterPort = confMachine.services.node-exporter.port;

  textfileDir = "/run/metrics";

  smartmon = pkgs.writeScript "smartmon.sh-wrapper" ''
    ${pkgs.node-exporter-textfile-collector-scripts}/bin/smartmon.sh > ${textfileDir}/smartmon.prom.$$
    mv ${textfileDir}/smartmon.prom.$$ ${textfileDir}/smartmon.prom
  '';

in {
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

    (mkIf cfg.enable {
      networking.firewall.extraCommands = concatStringsSep "\n" (map (d: ''
        # Allow access to node-exporter from ${d.config.host.fqdn}
        iptables -A nixos-fw -p tcp -m tcp -s ${d.config.addresses.primary.address} --dport ${toString nodeExporterPort} -j nixos-fw-accept
      '') monitorings);

      services.prometheus.exporters = {
        node = {
          enable = true;
          port = nodeExporterPort;
        };
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
      networking.firewall.extraCommands = concatStringsSep "\n" (map (d: ''
        # Allow access to ipmi-exporter from ${d.config.host.fqdn}
        iptables -A nixos-fw -p tcp -m tcp -s ${d.config.addresses.primary.address} --dport ${toString ipmiExporterPort} -j nixos-fw-accept
      '') monitorings);

      services.prometheus.exporters = {
        ipmi = {
          enable = true;
          port = ipmiExporterPort;
        };

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
      };

      services.cron.systemCronJobs = [
        "0 9 * * * root ${smartmon}"
      ];
    })
  ];
}
