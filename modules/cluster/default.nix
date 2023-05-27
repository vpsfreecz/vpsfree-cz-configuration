{ config, lib, confLib, ... }@args:
with lib;
let
  topLevelConfig = config;

  machine =
    { config, ... }:
    {
      options = {
        container = mkOption {
          type = types.nullOr (types.submodule container);
          default = null;
        };

        node = mkOption {
          type = types.nullOr (types.submodule node);
          default = null;
        };

        osNode = mkOption {
          type = types.nullOr (types.submodule osNode);
          default = null;
        };

        vzNode = mkOption {
          type = types.nullOr (types.submodule vzNode);
          default = null;
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
      };

      config = mkMerge [
        (mkIf (config.spin == "vpsadminos") {
          buildGenerations = {
            min = mkDefault 1;
            max = mkDefault 1;
          };

          hostGenerations = {
            min = mkDefault 3;
            max = mkDefault 6;
            maxAge = mkDefault (360*24*60*60);
          };

          healthChecks = {
            machineCommands = [
              { command = [ "osctl" "ping" ]; }
              { command = [ "nodectl" "ping" ]; }
            ];
          };
        })

        (mkIf (config.spin == "nixos") {
          buildGenerations = {
            min = mkDefault 1;
            max = mkDefault 1;
          };

          hostGenerations = {
            min = mkDefault 6;
            max = mkDefault 30;
            maxAge = mkDefault (60*24*60*60);
          };

          healthChecks = {
            systemd.unitProperties = {
              "firewall.service" = [
                { property = "ActiveState"; value = "active"; }
              ];
            };
          };
        })
      ];
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

  node = import ./nodes/common.nix;

  osNode = (import ./nodes/vpsadminos.nix) args;

  vzNode = (import ./nodes/openvz.nix) args;

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

in {
  imports = [
    ../services/definitions.nix
  ];

  options = {
    cluster = mkOption {
      type = types.attrsOf (types.submodule machine);
    };
  };
}
