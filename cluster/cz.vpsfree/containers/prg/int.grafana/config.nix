{
  pkgs,
  lib,
  confLib,
  config,
  confMachine,
  ...
}:
let
  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  grafanaPort = confMachine.services.grafana.port;
in
{
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
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = grafanaPort;
        domain = "grafana.prg.vpsfree.cz";
        root_url = "https://grafana.prg.vpsfree.cz/";
      };
      "auth.anonymous" = {
        enabled = true;
        org_name = "vpsFree.cz";
      };
    };
  };

  system.stateVersion = "22.05";
}
