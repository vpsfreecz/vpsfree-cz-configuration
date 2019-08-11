{ lib, config, pkgs, deploymentInfo, confLib, ... }:
with lib;
let
  cfg = config.system.monitoring;

  monPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "vpsfree.cz";
    location = "prg";
    name = "mon.int";
  };

  monitoringIPs = [
    monPrg.addresses.primary
  ];

  exporterPort = deploymentInfo.config.services.node-exporter.port;
in {
  options = {
    system.monitoring = {
      enable = mkEnableOption "Monitor this system";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.extraCommands = lib.concatStringsSep "\n" (map (ip:
      "iptables -A nixos-fw -p tcp -m tcp -s ${ip} --dport ${toString exporterPort} -j nixos-fw-accept"
    ) monitoringIPs);

    services.prometheus.exporters = {
      node = {
        enable = true;
        port = exporterPort;
        extraFlags = [ "--collector.textfile.directory=/run/metrics" ];
        enabledCollectors = [
          "vmstat"
          "interrupts"
          "textfile"
          "processes"
        ] ++ (lib.optionals (deploymentInfo.spin == "nixos") [ "systemd" "logind" ])
          ++ (lib.optionals (!config.boot.isContainer) [ "hwmon" "mdadm" "ksmd" ]);
      };
    };
  };
}
