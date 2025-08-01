{
  config,
  pkgs,
  lib,
  confLib,
  ...
}:
let
  inherit (lib) concatStringsSep filter;

  allMachines = confLib.getClusterMachines config.cluster;

  allNodes = filter (m: m.metaConfig.node != null && m.metaConfig.monitoring.enable) allMachines;

  nodeHosts = map (n: ''
    [${n.metaConfig.host.fqdn}]
    address ${n.metaConfig.addresses.primary.address}
    use_node_name yes
  '') allNodes;

  allHosts = concatStringsSep "\n\n" nodeHosts;

  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
in
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  services.munin-cron = {
    enable = true;
    hosts = allHosts;
    fastcgi = {
      enableGraph = true;
      socketUser = "nginx";
    };
  };

  services.nginx = {
    enable = true;

    virtualHosts."munin.vpsfree.cz" = {
      locations."/".root = "/var/www/munin";

      locations."^~ /munin-cgi/munin-cgi-graph/".extraConfig = ''
        access_log off;
        fastcgi_split_path_info ^(/munin-cgi/munin-cgi-graph)(.*);
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_pass unix:/run/munin/fastcgi-graph.sock;
        include ${pkgs.nginx}/conf/fastcgi_params;
      '';
    };
  };

  networking.firewall.extraCommands = ''
    # Allow access from proxy.prg
    iptables -A nixos-fw -p tcp --dport 80 -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept
  '';

  system.stateVersion = "23.11";
}
