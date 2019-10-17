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
      nginx = 80;
      nix-serve = 5000;
      node-exporter = 9100;
      osctl-exporter = 9101;
      graylog-rsyslog-tcp = 11514;
      graylog-rsyslog-udp = 11515;
      graylog-gelf = 12201;
    };
  };
}
