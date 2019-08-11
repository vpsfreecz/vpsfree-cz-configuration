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
      alertmanager = 9093;
      bird-bgp = 179;
      grafana = 3000;
      vpsadmin-console = 8081;
      prometheus = 9090;
      node-exporter = 9100;
      osctl-exporter = 9101;
    };
  };
}
