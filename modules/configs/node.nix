{ config, lib, confLib, confData, confMachine, ... }:
with lib;
let
  cfg = confMachine;

  useBird = cfg.osNode.networking.bird.enable;
  isBGP = useBird && cfg.osNode.networking.bird.routingProtocol == "bgp";
  isOSPF = useBird && cfg.osNode.networking.bird.routingProtocol == "ospf";

  mapEachIp = fn: addresses:
    flatten (mapAttrsToList (ifname: ips:
      (map (addr: fn ifname 4 addr) ips.v4)
      ++
      (map (addr: fn ifname 6 addr) ips.v6)
    ) addresses);

  allNetworks = confData.vpsadmin.networks.containers;

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
  config = mkIf (confMachine.osNode != null) {
    vpsadmin.nodectld = {
      nodeId = cfg.node.id;
      consoleHost = mkDefault confMachine.addresses.primary.address;
      netInterfaces = mkDefault (lib.attrNames cfg.osNode.networking.interfaces.addresses);
    };

    services.udev.extraRules = confLib.mkNetUdevRules cfg.osNode.networking.interfaces.names;
    services.rsyslogd.hostName = "${confMachine.name}.${confMachine.host.location}";

    networking.hostName = confMachine.host.fqdn;
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

    networking.bird = mkIf useBird {
      enable = true;
      routerId = cfg.osNode.networking.bird.routerId;

      protocol.kernel = {
        learn = true;
        persist = true;
        scanTime = mkIf isOSPF 2;
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

      protocol.device = {
        scanTime = mkIf isOSPF 2;
      };

      protocol.bfd = mkIf isBGP {
        enable = cfg.osNode.networking.bird.bfdInterfaces != "";
        interfaces."${cfg.osNode.networking.bird.bfdInterfaces}" = {};
      };

      protocol.bgp = mkIf isBGP (makeBirdBgp cfg.osNode.networking.bird.bgpNeighbours.v4);

      protocol.ospf = mkIf isOSPF {
        ospf1 = {
          extraConfig = ''
            import all;
            export all;
          '';

          area."0.0.0.0" = {
            networks = confData.vpsadmin.networks.ospf.${confMachine.host.location}.ipv4;

            interface = {
              "bond200" = {};
              "veth*" = {};
              "virtip" = {};
            };
          };
        };
      };
    };

    networking.bird6 = mkIf useBird {
      enable = true;
      routerId = cfg.osNode.networking.bird.routerId;

      protocol.kernel = {
        learn = true;
        persist = true;
        scanTime = mkIf isOSPF 2;
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

      protocol.device = {
        scanTime = mkIf isOSPF 2;
      };

      protocol.bfd = mkIf isBGP {
        enable = cfg.osNode.networking.bird.bfdInterfaces != "";
        interfaces."${cfg.osNode.networking.bird.bfdInterfaces}" = {};
      };

      protocol.bgp = mkIf isBGP (makeBirdBgp cfg.osNode.networking.bird.bgpNeighbours.v6);

      protocol.ospf = mkIf isOSPF {
        ospf1 = {
          extraConfig = ''
            import all;
            export all;
          '';

          area."0.0.0.0" = {
            networks = confData.vpsadmin.networks.ospf.${confMachine.host.location}.ipv6;

            interface = {
              "bond200" = {};
              "veth*" = {};
              "virtip" = {};
            };
          };
        };
      };
    };

    networking.firewall.extraCommands =
      let
        bgpPort = toString config.serviceDefinitions.bird-bgp.port;

        bgpRules = optionalString isBGP ''
          ${concatMapStringsSep "\n" (neigh: ''
          iptables -A nixos-fw -p tcp -s ${neigh.address} --dport ${bgpPort} -j nixos-fw-accept
          '') cfg.osNode.networking.bird.bgpNeighbours.v4}
          ${concatMapStringsSep "\n" (neigh: ''
          ip6tables -A nixos-fw -p tcp -s ${neigh.address} --dport ${bgpPort} -j nixos-fw-accept
          '') cfg.osNode.networking.bird.bgpNeighbours.v6}
        '';

        ospfProto = toString config.serviceDefinitions.bird-ospf.port;

        ospfRules = optionalString isOSPF ''
          iptables -A nixos-fw -p ${ospfProto} -j nixos-fw-accept
          ip6tables -A nixos-fw -p ${ospfProto} -j nixos-fw-accept
        '';
      in concatStringsSep "\n\n" [ bgpRules ospfRules ];

    system.monitoring.enable = true;
    osctl.exporter.port = confMachine.services.osctl-exporter.port;
  };
}
