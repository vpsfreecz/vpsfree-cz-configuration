{ config, lib, pkgs, confLib, confData, confMachine, ... }:
let
  inherit (lib) concatMapStringsSep filter optionals;

  formatNetworks = list: map (net: "${net.address}/${toString net.prefix}") list;

  containerV4Networks = formatNetworks confData.vpsadmin.networks.containers.ipv4;

  containerV6Networks = formatNetworks confData.vpsadmin.networks.containers.ipv6;

  managementV4Networks = formatNetworks confData.vpsadmin.networks.management.ipv4;

  v4Networks = [
    "172.16.0.0/12"
  ] ++ managementV4Networks
    ++ containerV4Networks
    ++ (optionals (confMachine.host.location == "brq") [
      # NAT in prg, needed in brq for access from monitoring
      "83.167.228.130/32"
      "81.31.40.98/32"
      "81.31.40.102/32"
    ]);

  v6Networks = containerV6Networks;

  allNetworks = v4Networks ++ v6Networks;

  kresdNetworks = [ "127.0.0.0/8" "::1/128" ] ++ allNetworks;

  managementPort = confMachine.services.kresd-management.port;

  allMachines = confLib.getClusterMachines config.cluster;

  monitors = filter (m: m.metaConfig.monitoring.isMonitor) allMachines;

  makeListenAddress = version: addr:
    if version == 4 then
      addr.address
    else
      "[${addr.address}]";

  makeListen = version: map (addr: "${makeListenAddress version addr}:${toString confMachine.services.kresd-plain.port}");
in {
  environment.systemPackages = with pkgs; [
    dnsutils
  ];

  fileSystems."/var/cache/knot-resolver" = {
    fsType = "tmpfs";
    device = "tmpfs";
    options = [ "rw,size=2G,uid=knot-resolver,gid=knot-resolver,nosuid,nodev,noexec,mode=0700" ];
  };

  services.kresd = {
    enable = true;
    package = pkgs.knot-resolver.override { extraFeatures = true; };
    instances = 8;
    listenPlain =
      (makeListen 4 [ { address = "127.0.0.1"; } ])
      ++ (makeListen 6 [ { address = "::1"; } ])
      ++ (makeListen 4 confMachine.addresses.v4)
      ++ (makeListen 6 confMachine.addresses.v6);
    extraConfig = ''
      net.listen(
        '${confMachine.addresses.primary.address}',
        ${toString confMachine.services.kresd-management.port},
        { kind = 'webmgmt' }
      )

      cache.size = cache.fssize() - 10*MB

      modules = {
        'view',
        'stats',
        'http'
      }

      http.config({
        tls = false,
      })

      http.prometheus.namespace = 'kresd_'

      -- allow access from our networks
      ${concatMapStringsSep "" (addr: ''
      view:addr('${addr}', policy.all(policy.PASS))
      '') kresdNetworks}

      -- drop everything that hasn't matched
      view:addr('0.0.0.0/0', policy.all(policy.DROP))
    '';
  };

  networking.firewall.extraCommands =
    (concatMapStringsSep "\n" (net: ''
      iptables -A nixos-fw -p udp -s ${net} --dport 53 -j nixos-fw-accept
      iptables -A nixos-fw -p tcp -s ${net} --dport 53 -j nixos-fw-accept
    '') v4Networks)
    + (concatMapStringsSep "\n" (net: ''
      ip6tables -A nixos-fw -p udp -s ${net} --dport 53 -j nixos-fw-accept
      ip6tables -A nixos-fw -p tcp -s ${net} --dport 53 -j nixos-fw-accept
    '') v6Networks)
    + (concatMapStringsSep "\n" (m: ''
      # kresd prometheus metrics ${m.name}
      iptables -A nixos-fw -p tcp --dport ${toString managementPort} -s ${m.metaConfig.addresses.primary.address} -j nixos-fw-accept
    '') monitors);
}
