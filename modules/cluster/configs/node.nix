{ config, lib, confLib, data, deploymentInfo, ... }:
with lib;
let
  cfg = deploymentInfo.config;

  mapEachIp = fn: addresses:
    flatten (mapAttrsToList (ifname: ips:
      (map (addr: fn ifname 4 addr) ips.v4)
      ++
      (map (addr: fn ifname 6 addr) ips.v6)
    ) addresses);

  allNetworks = data.networks.containers;

  importNetworkFilter = ipVer:
    let
      networks = allNetworks.${"ipv${toString ipVer}"};
      list = map (net: "${net.address}/${toString net.prefix}+") networks;
    in ''
      net ~ [ ${concatStringsSep ", " list} ]
    '';

  importInterfaceFilter = ipVer: optionalString (cfg.osNode.networking.interfaces.addresses != {}) (
    let
      ifconds = concatMapStringsSep " || " (v: "ifname = \"${v}\"") (attrNames cfg.osNode.networking.interfaces.addresses);
      netLen = {
        "ipv4" = 30;
        "ipv6" = 80;
      };
    in ''
      (${ifconds}) && net.len = ${toString netLen.${"ipv${toString ipVer}"}}
    '');

  makeBirdBgp = neighbours: listToAttrs (imap1 (i: neigh: nameValuePair "bgp${toString i}" {
    as = cfg.osNode.networking.bird.as;
    nextHopSelf = true;
    neighbor = { "${neigh.address}" = neigh.as; };
    extraConfig = ''
      export all;
      import all;
    '';
  }) neighbours);
in {
  config = mkIf (deploymentInfo.type == "node") {
    vpsadmin.nodeId = cfg.node.id;
    vpsadmin.consoleHost = mkDefault deploymentInfo.config.addresses.primary.address;
    vpsadmin.netInterfaces = mkDefault (lib.attrNames cfg.osNode.networking.interfaces.addresses);

    services.udev.extraRules = confLib.mkNetUdevRules cfg.osNode.networking.interfaces.names;
    services.rsyslogd.hostName = "${deploymentInfo.name}.${deploymentInfo.location}";

    networking.hostName = deploymentInfo.fqdn;
    networking.custom = ''
      ${concatStringsSep "\n" (mapEachIp (ifname: v: addr: ''
      ip -${toString v} addr add ${addr.string} dev ${ifname}
      '') cfg.osNode.networking.interfaces.addresses)}

      ${concatStringsSep "\n" (mapAttrsToList (ifname: ips: ''
        ip link set ${ifname} up
      '') cfg.osNode.networking.interfaces.addresses)}

      ${optionalString (!isNull cfg.osNode.networking.virtIP) ''
      ip link add virtip type dummy
      ip addr add ${cfg.osNode.networking.virtIP.string} dev virtip
      ip link set virtip up
      ''}
    '';

    networking.bird = mkIf cfg.osNode.networking.bird.enable {
      enable = true;
      routerId = cfg.osNode.networking.bird.routerId;
      protocol.kernel = {
        learn = true;
        persist = true;
        extraConfig = ''
          export all;
          import filter {
            if (${importNetworkFilter 4})
               || (${importInterfaceFilter 4})
               ${optionalString (cfg.osNode.networking.virtIP != null) ''|| (ifname = "virtip")''}
            then
              accept;
            else
              reject;
          };
        '';
      };
      protocol.bfd = {
        enable = cfg.osNode.networking.bird.bfdInterfaces != "";
        interfaces."${cfg.osNode.networking.bird.bfdInterfaces}" = {};
      };
      protocol.bgp = makeBirdBgp cfg.osNode.networking.bird.bgpNeighbours.v4;
    };

    networking.bird6 = mkIf cfg.osNode.networking.bird.enable {
      enable = true;
      routerId = cfg.osNode.networking.bird.routerId;
      protocol.kernel = {
        learn = true;
        persist = true;
        extraConfig = ''
          export all;
          import filter {
            if (${importNetworkFilter 6})
               || (${importInterfaceFilter 6})
            then
              accept;
            else
              reject;
          };
        '';
      };
      protocol.bfd = {
        enable = cfg.osNode.networking.bird.bfdInterfaces != "";
        interfaces."${cfg.osNode.networking.bird.bfdInterfaces}" = {};
      };
      protocol.bgp = makeBirdBgp cfg.osNode.networking.bird.bgpNeighbours.v6;
    };

    networking.firewall.extraCommands =
      let
        port = toString config.serviceDefinitions.bird-bgp.port;
      in optionalString cfg.osNode.networking.bird.enable ''
        ${concatMapStringsSep "\n" (neigh: ''
        iptables -A nixos-fw -p tcp -s ${neigh.address} --dport ${port} -j nixos-fw-accept
        '') cfg.osNode.networking.bird.bgpNeighbours.v4}
        ${concatMapStringsSep "\n" (neigh: ''
        ip6tables -A nixos-fw -p tcp -s ${neigh.address} --dport ${port} -j nixos-fw-accept
        '') cfg.osNode.networking.bird.bgpNeighbours.v6}
      '';

    boot.kernelParams = optionals cfg.osNode.serial.enable [
      "console=tty0"
      "console=ttyS0,${toString cfg.osNode.serial.baudRate}"
      "panic=-1"
    ];

    system.monitoring.enable = true;
    osctl.exporter.port = deploymentInfo.config.services.osctl-exporter.port;
  };
}
