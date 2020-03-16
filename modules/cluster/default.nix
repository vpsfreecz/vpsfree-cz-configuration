{ config, lib, ... }@args:
with lib;
let
  topLevelConfig = config;

  mkOptions = {
    addresses = v:
      { config, ... }:
      {
        options = {
          address = mkOption {
            type = types.str;
            description = "IPv${toString v} address";
          };

          prefix = mkOption {
            type = types.ints.positive;
            description = "Prefix length";
          };

          string = mkOption {
            type = types.str;
            default = "${config.address}/${toString config.prefix}";
            description = "Address with prefix as string";
          };
        };
      };
  };

  deployment =
    { config, ...}:
    {
      options = {
        type = mkOption {
          type = types.enum [ "node" "machine" "container" ];
          description = "Deployment type";
        };

        spin = mkOption {
          type = types.enum [ "openvz" "nixos" "vpsadminos" "other" ];
          description = "OS type";
        };

        addresses = {
          primary = mkOption {
            type = types.submodule (mkOptions.addresses 4);
            default = head config.addresses.v4;
            description = ''
              Default address other machines should use to connect to this machine

              Defaults to the first IPv4 address if not set
            '';
          };

          v4 = mkOption {
            type = types.listOf (types.submodule (mkOptions.addresses 4));
            default = [ config.addresses.primary ];
            description = ''
              List of IPv4 addresses this machine responds to
            '';
          };

          v6 = mkOption {
            type = types.listOf (types.submodule (mkOptions.addresses 6));
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
          apply = mapAttrs (name: sv:
            let
              def = topLevelConfig.serviceDefinitions.${name};
            in {
              address = if isNull sv.address then config.addresses.primary.address else sv.address;
              port = if isNull sv.port then def.port else sv.port;
              monitor = if isNull sv.monitor then def.monitor else sv.monitor;
            });
        };

        container = mkOption {
          type = types.nullOr (types.submodule container);
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

        logging = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Send logs to central log system
            '';
          };

          isLogger = mkOption {
            type = types.bool;
            default = false;
            description = ''
              This system is used as a central log system
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

        monitor = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            What kind of monitoring this services needs
          '';
        };
      };
    };

  container =
    { config, ... }:
    {
      options = {
        id = mkOption {
          type = types.int;
          description = "VPS ID in vpsAdmin";
        };
      };
    };

  node = (import ./nodes/common.nix) args;

  osNode = (import ./nodes/vpsadminos.nix) (args // { inherit mkOptions; });

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
