{ config, lib, ... }:
with lib;
let
  service =
    { config, ... }:
    {
      options = {
        port = mkOption {
          type = types.int;
          description = ''
            Default port the service listens on
          '';
        };

        monitor = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Default monitoring the service needs
          '';
        };
      };
    };
in {
  options = {
    serviceDefinitions = mkOption {
      type = types.attrsOf (types.submodule service);
      description = ''
        Mapping of services to ports and other options
      '';
    };
  };

  config = {
    serviceDefinitions = {
      alertmanager.port = 9093;
      bind = {
        port = 53;
        monitor = "dns-authoritative";
      };
      bird-bgp.port = 179;
      buildbot-master.port = 8010;
      grafana.port = 3000;
      vpsadmin-console.port = 8081;
      prometheus.port = 9090;
      nginx.port = 80;
      nix-serve.port = 5000;
      node-exporter.port = 9100;
      osctl-exporter.port = 9101;
      graylog-rsyslog-tcp.port = 11514;
      graylog-rsyslog-udp.port = 11515;
      graylog-gelf.port = 12201;
      unbound = {
        port = 53;
        monitor = "dns-resolver";
      };
    };
  };
}
