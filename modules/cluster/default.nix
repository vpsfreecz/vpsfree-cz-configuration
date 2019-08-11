{ config, lib, ... }@args:
with lib;
let
  topLevelConfig = config;

  deployment =
    { config, ...}:
    {
      options = {
        type = mkOption {
          type = types.enum [ "node" "machine" "container" ];
          description = "Deployment type";
        };

        spin = mkOption {
          type = types.enum [ "openvz" "nixos" "vpsadminos" ];
          description = "OS type";
        };

        addresses = {
          primary = mkOption {
            type = types.str;
            default = head config.addresses.v4;
            description = ''
              Default address other machines should use to connect to this machine

              Defaults to the first IPv4 address if not set
            '';
          };

          v4 = mkOption {
            type = types.listOf types.str;
            default = [ config.addresses.primary ];
            description = ''
              List of IPv4 addresses this machine responds to
            '';
          };

          v6 = mkOption {
            type = types.listOf types.str;
            default = [];
            description = ''
              List of IPv6 addresses this machine responds to
            '';
          };
        };

        netboot = {
          enable = mkEnableOption "Include this system on pxe servers";
          macs = mkOption {
            type = types.listOf types.str;
            default = [];
            description = ''
              List of MAC addresses for iPXE node auto-detection
            '';
          };
        };

        services = mkOption {
          type = types.attrsOf (types.submodule service);
          default = {};
          description = ''
            Services published by this machine
          '';
          apply = mapAttrs (name: sv: {
            address = if isNull sv.address then config.addresses.primary else sv.address;
            port = if isNull sv.port then topLevelConfig.servicePorts.${name} else sv.port;
          });
        };

        node = mkOption {
          type = types.nullOr (types.submodule node);
        };

        osNode = mkOption {
          type = types.nullOr (types.submodule osNode);
        };

        vzNode = mkOption {
          type = types.nullOr (types.submodule vzNode);
        };

        monitoring = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Monitor this system
            '';
          };

          isMonitor = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Determines if this system is monitoring other systems, or if it
              is just being monitored
            '';
          };

          labels = mkOption {
            type = types.attrs;
            default = {};
            description = ''
              Custom labels added to the Prometheus target
            '';
          };
        };
      };
    };

  service =
    { config, ... }:
    {
      options = {
        address = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Address that other machines can access the service on
          '';
        };

        port = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = ''
            Port the service listens on
          '';
        };
      };
    };

  node = (import ./nodes/common.nix) args;

  osNode = (import ./nodes/vpsadminos.nix) args;

  vzNode = (import ./nodes/openvz.nix) args;
in {
  options = {
    cluster = mkOption {
      #      domain         location       name           deployment
      type = types.attrsOf (types.attrsOf (types.attrsOf (types.submodule deployment)));
      default = {};
    };
  };
}
