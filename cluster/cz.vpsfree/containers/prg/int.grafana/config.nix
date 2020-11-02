{ pkgs, lib, confLib, config, deploymentInfo, ... }:
let
  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  grafanaPort = deploymentInfo.services.grafana.port;
in {
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
  ];

  networking = {
    firewall.extraCommands = ''
      # Allow access to grafana from proxy.prg
      iptables -A nixos-fw -p tcp --dport ${toString grafanaPort} -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept
    '';
  };

  services.grafana = {
    enable = true;
    addr = "0.0.0.0";
    port = grafanaPort;
    domain = "grafana.prg.vpsfree.cz";
    rootUrl = "https://grafana.prg.vpsfree.cz/";
    auth.anonymous = {
      enable = true;
      org_name = "vpsFree.cz";
    };
  };
}
