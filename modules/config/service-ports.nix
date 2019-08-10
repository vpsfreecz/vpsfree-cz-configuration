{ config, lib, ... }:
with lib;
{
  options = {
    servicePorts = mkOption {
      type = types.attrsOf types.int;
      description = ''
        Mapping of services to ports
      '';
    };
  };

  config = {
    servicePorts = {
      node-exporter = 9100;
      osctl-exporter = 9101;
    };
  };
}
