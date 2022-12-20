{ lib, config, pkgs, confMachine, confLib, ... }:
with lib;
let
  cfg = config.system.monitoring;

  allMachines = confLib.getClusterMachines config.cluster;

  monitorings = filter (d: d.config.monitoring.isMonitor) allMachines;

  exporterPort = confMachine.services.node-exporter.port;

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
        iptables -A nixos-fw -p tcp -m tcp -s ${d.config.addresses.primary.address} --dport ${toString exporterPort} -j nixos-fw-accept
      '') monitorings);

      services.prometheus.exporters = {
        node = {
          enable = true;
          port = exporterPort;
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
    })

    # vpsAdminOS nodes
    (mkIf (cfg.enable && confMachine.spin == "vpsadminos") {
      services.prometheus.exporters.node = {
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
      };

      services.cron.systemCronJobs = [
        "0 9 * * * root ${smartmon}"
      ];
    })
  ];
}
