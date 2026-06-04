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

  muninConf = pkgs.writeText "munin.conf" ''
    dbdir     /var/lib/munin
    cgitmpdir /run/munin/cgi-tmp
    htmldir   /var/www/munin
    logdir    /var/log/munin
    rundir    /run/munin

    ${allHosts}
  '';

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
    extraGlobalConfig = ''
      cgitmpdir /run/munin/cgi-tmp
    '';
  };

  systemd.services.munin-cgi-graph = {
    wantedBy = [ "multi-user.target" ];
    environment.MUNIN_CONFIG = muninConf;
    serviceConfig = {
      Type = "forking";
      Restart = "always";
      ExecStart = ''
        ${pkgs.spawn_fcgi}/bin/spawn-fcgi \
          -u munin \
          -g munin \
          -U nginx \
          -M 0600 \
          -s /run/munin/fastcgi-graph.sock \
          -- ${pkgs.munin}/www/cgi/munin-cgi-graph
      '';
    };
  };

  systemd.tmpfiles.settings."25-munin-cgi"."/run/munin/cgi-tmp".d = {
    mode = "0755";
    user = "munin";
    group = "munin";
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
