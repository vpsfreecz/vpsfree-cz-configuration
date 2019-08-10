{ config, lib, ... }:
with lib;
let
  node = {
    options = {
      nodeId = mkOption {
        type = types.ints.positive;
        description = "ID of this node in vpsAdmin";
      };

      networking = {
        netboot = {
          enable = mkEnableOption "Include this node on pxe servers";
          macs = mkOption {
            type = types.listOf types.str;
            default = [];
            description = ''
              List of MAC addresses for iPXE node auto-detection
            '';
          };
        };

        interfaces = {
          names = mkOption {
            type = types.attrsOf types.str;
            default = {};
            example = { teng0 = "00:11:22:33:44:55"; };
            description = ''
              Ensure network interface names based on MAC addresses
            '';
          };

          addresses = mkOption {
            type = types.attrsOf (types.submodule interfaceAddresses);
            default = {};
            example = {
              teng0 = {
                v4 = [ "1.2.3.4/32" ];
                v6 = [];
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

          as = mkOption {
            type = types.ints.positive;
            description = "BGP AS for this node";
          };

          routerId = mkOption {
            type = types.str;
            description = "bird router ID";
          };

          bgpNeighbours = {
            v4 = mkOption {
              type = types.listOf (types.submodule (bgpNeighbour 4));
              default = [];
              description = "IPv4 BGP neighbour addresses";
            };
            v6 = mkOption {
              type = types.listOf (types.submodule (bgpNeighbour 6));
              default = [];
              description = "IPv6 BGP neighbour addresses";
            };
          };

          bfdInterfaces = mkOption {
            type = types.str;
            description = "BFD interfaces match";
            example = "teng*";
            default = "teng*";
          };
        };

        virtIP = mkOption {
          type = types.nullOr types.str;
          description = "Virtual IP for dummy interface";
          example = "10.0.0.100/32";
        };
      };

      serial = {
        enable = mkEnableOption "Enable serial console output";
        baudRate = mkOption {
          type = types.ints.positive;
          description = "Serial baudrate";
          default = 115200;
        };
      };
    };
  };

  interfaceAddresses = {
    options = {
      v4 = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          A lisf of IPv4 addresses with prefix
        '';
      };
      v6 = mkOption {
        type = types.listOf types.str;
        default = [];
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
    };
  };
in node
