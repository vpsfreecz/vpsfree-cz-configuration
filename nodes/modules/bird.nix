{ config, lib, ...}:
with lib;

let
  cfg = config.node.net;

  allNetworks = import ../../data/networks.nix;

  importNetworkFilter = ipVer:
    let
      networks = allNetworks.${"ipv${toString ipVer}"};
      list = map (net: "${net.address}/${toString net.prefix}+") networks;
    in ''
      net ~ [ ${concatStringsSep ", " list} ]
    '';

  importInterfaceFilter = ipVer: optionalString (cfg.interfaces != {}) (
    let
      ifconds = concatMapStringsSep " || " (v: "ifname = \"${v}\"") (attrNames cfg.interfaces);
      netLen = {
        "ipv4" = 30;
        "ipv6" = 80;
      };
    in ''
      (${ifconds}) && net.len = ${toString netLen.${"ipv${toString ipVer}"}}
    '');

  bgpNeighborOpts = { lib, pkgs, ... }: {
    options = {
      v4 = mkOption {
        type = types.str;
      };
      v6 = mkOption {
        type = types.str;
      };
    };
  };
in
{
  options = {
    node.net = {
      as = mkOption {
        type = types.ints.positive;
        description = "BGP AS for this node";
      };

      bfdInterfaces = mkOption {
        type = types.str;
        description = "BFD interfaces match";
        example = "teng*";
        default = "teng*";
      };

      routerId = mkOption {
        type = types.str;
        description = "bird router ID";
      };

      bgp1neighbor = mkOption {
        type = types.submodule bgpNeighborOpts;
      };
      bgp2neighbor = mkOption {
        type = types.submodule bgpNeighborOpts;
      };
    };
  };
  config = {
    networking.bird = {
      enable = true;
      routerId = cfg.routerId;
      protocol.kernel = {
        learn = true;
        persist = true;
        extraConfig = ''
          export all;
          import filter {
            if (${importNetworkFilter 4})
               || (${importInterfaceFilter 4})
               ${optionalString (cfg.virtIP != null) ''|| (ifname = "virtip")''}
            then
              accept;
            else
              reject;
          };
        '';
      };
      protocol.bfd = {
        enable = cfg.bfdInterfaces != "";
        interfaces."${cfg.bfdInterfaces}" = {};
      };
      protocol.bgp = {
        bgp1 = {
          as = cfg.as;
          nextHopSelf = true;
          neighbor = { "${cfg.bgp1neighbor.v4}" = 4200001901; };
          extraConfig = ''
            export all;
            import all;
          '';
        };
        bgp2 = {
          as = cfg.as;
          nextHopSelf = true;
          neighbor = { "${cfg.bgp2neighbor.v4}" = 4200001902; };
          extraConfig = ''
            export all;
            import all;
          '';
        };
      };
    };

    networking.bird6 = {
      enable = true;
      routerId = cfg.routerId;
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
        enable = cfg.bfdInterfaces != "";
        interfaces."${cfg.bfdInterfaces}" = {};
      };
      protocol.bgp = {
        bgp1 = {
          as = cfg.as;
          nextHopSelf = true;
          neighbor = { "${cfg.bgp1neighbor.v6}" = 4200001901; };
          extraConfig = ''
            export all;
            import all;
          '';
        };
        bgp2 = {
          as = cfg.as;
          nextHopSelf = true;
          neighbor = { "${cfg.bgp2neighbor.v6}" = 4200001902; };
          extraConfig = ''
            export all;
            import all;
          '';
        };
      };
    };

    networking.firewall.extraCommands = let port = "179"; in ''
      iptables -A nixos-fw -p tcp -s ${cfg.bgp1neighbor.v4} --dport ${port} -j nixos-fw-accept
      iptables -A nixos-fw -p tcp -s ${cfg.bgp2neighbor.v4} --dport ${port} -j nixos-fw-accept
      ip6tables -A nixos-fw -p tcp -s ${cfg.bgp1neighbor.v6} --dport ${port} -j nixos-fw-accept
      ip6tables -A nixos-fw -p tcp -s ${cfg.bgp2neighbor.v6} --dport ${port} -j nixos-fw-accept
    '';
  };
}
