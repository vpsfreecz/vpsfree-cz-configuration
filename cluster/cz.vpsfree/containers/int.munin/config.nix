{ config, pkgs, lib, confLib, ... }:
let
  inherit (lib) concatStringsSep filter;

  allMachines = confLib.getClusterMachines config.cluster;

  allNodes = filter (m: m.config.node != null && m.config.monitoring.enable) allMachines;

  nodeHosts = map (n: ''
    [${n.config.host.fqdn}]
    address ${n.config.addresses.primary.address}
    use_node_name yes
  '') allNodes;

  allHosts = concatStringsSep "\n\n" nodeHosts;

  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  services.munin-cron = {
    enable = true;
    hosts = allHosts;
  };

  services.nginx = {
    enable = true;

    virtualHosts."munin.vpsfree.cz" = {
      locations."/".root = "/var/www/munin";
    };
  };

  networking.firewall.extraCommands = ''
    # Allow access from proxy.prg
    iptables -A nixos-fw -p tcp --dport 80 -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept
  '';

  system.stateVersion = "23.11";
}
