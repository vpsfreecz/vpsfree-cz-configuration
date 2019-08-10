{ config, lib, ... }@args:
with lib;
let
  topLevelConfig = config;

  deployment =
    { config, ...}:
    {
      options = {
        addresses = {
          main = mkOption {
            type = types.str;
            default = head config.addresses.v4;
            description = ''
              Default address other machines should use to connect to this machine

              Defaults to the first IPv4 address if not set
            '';
          };

          v4 = mkOption {
            type = types.listOf types.str;
            default = [ config.main ];
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

        services = mkOption {
          type = types.attrsOf (types.submodule service);
          default = {};
          description = ''
            Services published by this machine
          '';
          apply = mapAttrs (name: sv: {
            address = if isNull sv.address then config.addresses.main else sv.address;
            port = if isNull sv.port then topLevelConfig.servicePorts.${name} else sv.port;
          });
        };

        osNode = mkOption {
          type = types.nullOr (types.submodule osNode);
        };

        vzNode = mkOption {
          type = types.nullOr (types.submodule vzNode);
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
