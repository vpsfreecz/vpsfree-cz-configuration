{ config, lib, ...}:
with lib;

let
  cfg = config.node;
in
{
  options = {
    node = {
      nodeId = mkOption {
        type = types.ints.positive;
        description = "ID of this node";
      };
    };
  };
  config = {
    vpsadmin.nodeId = cfg.nodeId;
    vpsadmin.consoleHost = mkDefault cfg.net.routerId;
    vpsadmin.netInterfaces = mkDefault (lib.mapAttrsToList (name: val: name) cfg.net.interfaces);
  };
}
