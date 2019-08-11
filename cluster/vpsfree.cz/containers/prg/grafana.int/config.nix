{ pkgs, lib, confLib, config, deploymentInfo, ... }:
let
  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "vpsfree.cz";
    location = "prg";
    name = "proxy";
  };

  grafanaPort = deploymentInfo.config.services.grafana.port;
in {
  imports = [
    ../../../../../environments/base.nix
  ];

  system.monitoring.enable = true;

  networking = {
    firewall.extraCommands = ''
      # Allow access to grafana from proxy.prg
      iptables -A nixos-fw -p tcp --dport ${toString grafanaPort} -s ${proxyPrg.addresses.primary} -j nixos-fw-accept
    '';
  };

  services.grafana = {
    enable = true;
    addr = "0.0.0.0";
    port = grafanaPort;
    domain = "grafana.prg.vpsfree.cz";
    rootUrl = "https://grafana.prg.vpsfree.cz/";
  };
}
