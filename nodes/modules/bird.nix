{ config, lib, ...}:
with lib;

let
  cfg = config.node.net;
  kernelProto = {
      learn = true;
      persist = true;
      extraConfig = ''
        export all;
        import all;
        import filter {
          if net.len > 25 then accept;
          reject;
        };
      '';
    };
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
      protocol.kernel = kernelProto;
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
      protocol.kernel = kernelProto;
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
  };
}
