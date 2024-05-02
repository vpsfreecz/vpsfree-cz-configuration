{ config, pkgs, lib, confLib, confMachine, confData, ... }:
let
  inherit (lib) concatMapStringsSep filter mkForce;

  allMachines = confLib.getClusterMachines config.cluster;

  monitors = filter (m: m.metaConfig.monitoring.isMonitor) allMachines;

  exporterPort = confMachine.services.bind-exporter.port;
in {
  environment.systemPackages = with pkgs; [
    config.services.bind.package
    dnsutils
  ];

  services.bind = {
    enable = true;
    forwarders = mkForce [];
    extraOptions = ''
      recursion no;
      allow-query-cache { none; };
    '';
    extraConfig = ''
      statistics-channels {
        inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
      };
    '';
  };

  services.prometheus.exporters.bind = {
    enable = true;
    port = exporterPort;
  };

  networking.resolvconf.useLocalResolver = false;

  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  networking.firewall.extraCommands =
    (concatMapStringsSep "\n" (m: ''
      # bind-exporter from ${m.name}
      iptables -A nixos-fw -p tcp --dport ${toString exporterPort} -s ${m.metaConfig.addresses.primary.address} -j nixos-fw-accept
    '') monitors);

  users.users.root.openssh.authorizedKeys.keys = [ confData.sshKeys.krcmar ];
}
