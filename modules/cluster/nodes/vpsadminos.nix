{
  config,
  lib,
  confLib,
  ...
}:
with lib;
let
  node = {
    options = {
      networking = {
        interfaces = {
          names = mkOption {
            type = types.attrsOf types.str;
            default = { };
            example = {
              teng0 = "00:11:22:33:44:55";
            };
            description = ''
              Ensure network interface names based on MAC addresses
            '';
          };

          addresses = mkOption {
            type = types.attrsOf (types.submodule interfaceAddresses);
            default = { };
            example = {
              teng0 = {
                v4 = [ "1.2.3.4/32" ];
                v6 = [ ];
              };
            };
            description = ''
              List of addresses which are added to interfaces
            '';
          };
        };

        bird = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable BGP routing using bird";
          };

          logFile = mkOption {
            type = types.str;
            default = "/var/log/bird.log";
          };

          logVerbosity = mkOption {
            type = types.str;
            default = "all";
          };

          as = mkOption {
            type = types.nullOr types.ints.positive;
            default = null;
            description = "BGP AS for this node";
          };

          routerId = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "bird router ID";
          };

          routingProtocol = mkOption {
            type = types.enum [
              "bgp"
              "ospf"
            ];
            default = "bgp";
            description = "Routing protocol";
          };

          bgpNeighbours = {
            v4 = mkOption {
              type = types.listOf (types.submodule (bgpNeighbour 4));
              default = [ ];
              description = "IPv4 BGP neighbour addresses";
            };
            v6 = mkOption {
              type = types.listOf (types.submodule (bgpNeighbour 6));
              default = [ ];
              description = "IPv6 BGP neighbour addresses";
            };
          };

          bfdInterfaces = mkOption {
            type = types.str;
            description = "BFD interfaces match";
            example = "teng*";
            default = "teng*";
          };

          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Extra lines appended to the BIRD Internet Routing Daemon
              configuration file.
              <link xlink:href='http://bird.network.cz/'/>
            '';
          };
        };

        virtIP = mkOption {
          type = types.nullOr (types.submodule (confLib.mkOptions.addresses 4));
          default = null;
          description = "Virtual IP for dummy interface";
          example = {
            address = "10.0.0.100";
            prefix = 32;
          };
        };
      };
    };
  };

  interfaceAddresses = {
    options = {
      v4 = mkOption {
        type = types.listOf (types.submodule (confLib.mkOptions.addresses 4));
        default = [ ];
        description = ''
          A lisf of IPv4 addresses with prefix
        '';
      };
      v6 = mkOption {
        type = types.listOf (types.submodule (confLib.mkOptions.addresses 4));
        default = [ ];
        description = ''
          A lisf of IPv6 addresses with prefix
        '';
      };
    };
  };

  bgpNeighbour = v: {
    options = {
      address = mkOption {
        type = types.str;
        description = "IPv${toString v} address";
      };

      as = mkOption {
        type = types.int;
        description = "BGP AS";
      };

      keepaliveTime = mkOption {
        type = types.nullOr types.int;
        default = 60;
        description = "BGP keepalive time, null for BIRD default";
      };

      holdTime = mkOption {
        type = types.nullOr types.int;
        default = 240;
        description = "BGP hold time, null for BIRD default";
      };
    };
  };
in
node
