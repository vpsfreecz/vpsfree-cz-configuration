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
      kresd-plain = {
        port = 53;
        monitor = "dns-resolver";
      };
      bind-exporter = {
        port = 9119;
        monitor = "bind-exporter";
      };
      bepasty.port = 8000;
      bird-ospf.port = 89;
      bird-bgp.port = 179;
      buildbot-master.port = 8010;
      geminabox.port = 8000;
      grafana.port = 3000;
      vpsadmin-console.port = 8081;
      prometheus.port = 9090;
      munin-cron.port = -1;
      nginx.port = 80;
      nix-serve.port = 5000;
      haproxy-exporter = {
        port = 8405;
        monitor = "haproxy-exporter";
      };
      kresd-management = {
        port = 8453;
        monitor = "kresd-management";
      };
      ipmi-exporter.port = 9290;
      node-exporter.port = 9100;
      osctl-exporter.port = 9101;
      rabbitmq-exporter = {
        port = 15692;
        monitor = "rabbitmq";
      };
      syslog-exporter.port = 9102;
      ssh-exporter = {
        port = 9103;
        monitor = "ssh-exporter";
      };
      ksvcmon-exporter.port = 9299;
      rsyslog-tcp.port = 11514;
      rsyslog-udp.port = 11515;
      sachet.port = 9876;
    };
  };
}
