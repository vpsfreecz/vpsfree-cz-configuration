{ config, lib, ...}:
with lib;
with (import ../lib.nix { inherit lib; });

let
  cfg = config.node.net;
  ifcOpts = { lib, pkgs, ... }: {
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
      mac = mkOption {
        type = types.attrsOf types.str;
        description = "Interface to its MAC mappings for udev rules";
        example = {
          teng0 = "00:25:90:0e:5b:1a";
          teng1 = "00:25:90:0e:5b:1b";
        };
      };

      interfaces = mkOption {
        type = types.attrsOf (types.submodule ifcOpts);
        description = "Network config";
      };

      hostName = mkOption {
        type = types.str;
        description = "Hostname of this node";
      };

      virtIP = mkOption {
        type = types.nullOr types.str;
        description = "Virtual IP for dummy interface";
        example = "10.0.0.100/32";
      };
    };
  };
  config = {
    services.udev.extraRules = mkNetUdevRules cfg.mac;

    networking.hostName = cfg.hostName;
    networking.custom = ''
      ${concatStringsSep "\n" (flip mapAttrsToList cfg.interfaces (ifname: ifc: ''
      ip addr add ${ifc.v4} dev ${ifname}
      ip -6 addr add ${ifc.v6} dev ${ifname}
      ''))}
      ${concatStringsSep "\n" (flip mapAttrsToList cfg.interfaces (ifname: ifc: ''
        ip link set ${ifname} up
      ''))}

      ${optionalString (!isNull cfg.virtIP) ''
      ip link add virtip type dummy
      ip addr add ${cfg.virtIP} dev virtip
      ip link set virtip up
      ''}
    '';
  };
}
