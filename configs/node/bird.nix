{ config, lib, confLib, confData, confMachine, ... }:
with lib;
let
  cfg = confMachine;
  birdCfg = cfg.osNode.networking.bird;

  useBird = birdCfg.enable;
  isBGP = useBird && birdCfg.routingProtocol == "bgp";
  isOSPF = useBird && birdCfg.routingProtocol == "ospf";

  kernelScanTime = if isBGP then "10" else "2";
  deviceScanTime = if isBGP then "1" else "2";

  concatNl = concatStringsSep "\n";

  birdConfig = ''
    router id ${birdCfg.routerId};
    log "${birdCfg.logFile}" ${birdCfg.logVerbosity};

    protocol kernel kernel4 {
      persist;
      learn;
      scan time ${kernelScanTime};

      ipv4 {
        export all;
        import filter {
          if (${importNetworkFilter 4})
             ${optionalString isBGP "|| (${importInterfaceFilter 4})"}
             ${optionalString (cfg.osNode.networking.virtIP != null) ''|| (ifname = "virtip")''}
          then
            accept;
          else
            reject;
        };
      };
    }

    protocol kernel kernel6 {
      persist;
      learn;
      scan time ${kernelScanTime};

      ipv6 {
        export all;
        import filter {
          if (${importNetworkFilter 6})
             ${optionalString isBGP "|| (${importInterfaceFilter 6})"}
             ${optionalString (cfg.osNode.networking.virtIP != null) ''|| (ifname = "virtip")''}
          then
            accept;
          else
            reject;
        };
      };
    }

    protocol device {
      scan time ${deviceScanTime};
    }

    ${optionalString isBGP ''
    protocol direct {
      ipv4;
      ipv6;
      interface "*";
    }

    ${bgpFragment "ipv4" birdCfg.bgpNeighbours.v4 0}

    ${bgpFragment "ipv6" birdCfg.bgpNeighbours.v6 (length birdCfg.bgpNeighbours.v4)}

    protocol bfd {
      interface "teng*" {
        min rx interval 10 ms;
        min tx interval 100 ms;
        idle tx interval 1000 ms;
      };
    }
    ''}

    ${optionalString isOSPF ''
    ${ospfFragment "ipv4" 4}
    ${ospfFragment "ipv6" 6}
    ''}

    ${birdCfg.extraConfig}
  '';

  bgpFragment = proto: neighbours: startIndex: concatNl (imap0 (i: neighbour: ''
    protocol bgp bgp${toString (startIndex + i)} {
      local as ${toString birdCfg.as};
      neighbor ${neighbour.address} as ${toString neighbour.as};

      ${proto} {
        export all;
        import all;
      };

      graceful restart;
    }
  '') neighbours);

  ospfFragment = proto: i: ''
    protocol ospf ${if proto == "ipv4" then "v2" else "v3"} ospf${toString i} {
      area 0.0.0.0 {
        networks {
          ${concatMapStringsSep "\n      " (v: "${v};") confData.vpsadmin.networks.ospf.${confMachine.host.location}.${proto}}
        };

        interface "bond0" {
        };

        interface "veth*" {
        };
      };

      ${proto} {
        import all;
        export all;
      };
    }
  '';

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
in {
  config = mkIf (confMachine.osNode != null) {
    services.bird2 = mkIf useBird {
      enable = true;

      preStartCommands = ''
        touch ${birdCfg.logFile}
        chown ${config.services.bird2.user}:${config.services.bird2.group} ${birdCfg.logFile}
        chmod 660 ${birdCfg.logFile}
      '';

      config = birdConfig;
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
  };
}
