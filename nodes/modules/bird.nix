{ config, lib, ...}:
with lib;

let
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
in
{
  options = {
    node = {
      as = mkOption {
        type = types.ints.positive;
        description = "BGP AS for this node";
      };

      bfdInterfaces = mkOption {
        type = types.str;
        description = "BFD interfaces match";
        example = "teng*";
      };

      routerId = mkOption {
        type = types.str;
        description = "bird router ID";
      };
    };
  };
  config = {
    networking.bird = {
      enable = true;
      routerId = config.node.routerId;
      protocol.kernel = kernelProto;
      protocol.bfd = {
        enable = config.node.bfdInterfaces != "";
        interfaces."${config.node.bfdInterfaces}" = {};
      };
      protocol.bgp = {
        bgp1 = {
          as = config.node.as;
          nextHopSelf = true;
          neighbor = { "172.16.251.1" = 4200001901; };
          extraConfig = ''
            export all;
            import all;
          '';
        };
        bgp2 = {
          as = config.node.as;
          nextHopSelf = true;
          neighbor = { "172.16.250.1" = 4200001902; };
          extraConfig = ''
            export all;
            import all;
          '';
        };
      };
    };

    networking.bird6 = {
      enable = true;
      routerId = config.node.routerId;
      protocol.kernel = kernelProto;
      protocol.bfd = {
        enable = config.node.bfdInterfaces != "";
        interfaces."${config.node.bfdInterfaces}" = {};
      };
      protocol.bgp = {
        bgp1 = {
          as = config.node.as;
          nextHopSelf = true;
          neighbor = { "2a03:3b40:42:2:01::1" = 4200001901; };
          extraConfig = ''
            export all;
            import all;
          '';
        };
        bgp2 = {
          as = config.node.as;
          nextHopSelf = true;
          neighbor = { "2a03:3b40:42:3:01::1" = 4200001902; };
          extraConfig = ''
            export all;
            import all;
          '';
        };
      };
    };
  };
}
