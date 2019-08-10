{ config, lib, data, deploymentInfo, ... }:
with lib;
with (import ../lib.nix { inherit lib; });
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

  importInterfaceFilter = ipVer: optionalString (cfg.networking.interfaces != {}) (
    let
      ifconds = concatMapStringsSep " || " (v: "ifname = \"${v}\"") (attrNames cfg.networking.interfaces);
      netLen = {
        "ipv4" = 30;
        "ipv6" = 80;
      };
    in ''
      (${ifconds}) && net.len = ${toString netLen.${"ipv${toString ipVer}"}}
    '');

  makeBirdBgp = neighbours: listToAttrs (imap1 (i: neigh: nameValuePair "bgp${toString i}" {
    as = cfg.networking.bird.as;
    nextHopSelf = true;
    neighbor = { "${neigh.address}" = neigh.as; };
    extraConfig = ''
      export all;
      import all;
    '';
  }) neighbours);
in {
  config = mkIf (deploymentInfo.type == "node") {
    vpsadmin.nodeId = cfg.nodeId;
    vpsadmin.consoleHost = mkDefault cfg.networking.bird.routerId;
    vpsadmin.netInterfaces = mkDefault (lib.attrNames cfg.networking.interfaces.addresses);

    services.udev.extraRules = mkNetUdevRules cfg.networking.interfaces.names;

    networking.hostName = deploymentInfo.fqdn;
    networking.custom = ''
      ${concatStringsSep "\n" (mapEachIp (ifname: v: addr: ''
      ip -${toString v} addr add ${addr} dev ${ifname}
      '') cfg.networking.interfaces.addresses)}

      ${concatStringsSep "\n" (mapAttrsToList (ifname: ips: ''
        ip link set ${ifname} up
      '') cfg.networking.interfaces.addresses)}

      ${optionalString (!isNull cfg.networking.virtIP) ''
      ip link add virtip type dummy
      ip addr add ${cfg.networking.virtIP} dev virtip
      ip link set virtip up
      ''}
    '';

    networking.bird = mkIf cfg.networking.bird.enable {
      enable = true;
      routerId = cfg.networking.bird.routerId;
      protocol.kernel = {
        learn = true;
        persist = true;
        extraConfig = ''
          export all;
          import filter {
            if (${importNetworkFilter 4})
               || (${importInterfaceFilter 4})
               ${optionalString (cfg.networking.virtIP != null) ''|| (ifname = "virtip")''}
            then
              accept;
            else
              reject;
          };
        '';
      };
      protocol.bfd = {
        enable = cfg.networking.bird.bfdInterfaces != "";
        interfaces."${cfg.networking.bird.bfdInterfaces}" = {};
      };
      protocol.bgp = makeBirdBgp cfg.networking.bird.bgpNeighbours.v4;
    };

    networking.bird6 = mkIf cfg.networking.bird.enable {
      enable = true;
      routerId = cfg.networking.bird.routerId;
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
        enable = cfg.networking.bird.bfdInterfaces != "";
        interfaces."${cfg.networking.bird.bfdInterfaces}" = {};
      };
      protocol.bgp = makeBirdBgp cfg.networking.bird.bgpNeighbours.v6;
    };

    networking.firewall.extraCommands =
      let
        port = "179";
      in optionalString cfg.networking.bird.enable ''
        ${concatMapStringsSep "\n" (neigh: ''
        iptables -A nixos-fw -p tcp -s ${neigh.address} --dport ${port} -j nixos-fw-accept
        '') cfg.networking.bird.bgpNeighbours.v4}
        ${concatMapStringsSep "\n" (neigh: ''
        ip6tables -A nixos-fw -p tcp -s ${neigh.address} --dport ${port} -j nixos-fw-accept
        '') cfg.networking.bird.bgpNeighbours.v6}
      '';

    boot.kernelParams = optionals cfg.serial.enable [
      "console=tty0"
      "console=ttyS0,${toString cfg.baudRate}"
      "panic=-1"
    ];
  };
}
