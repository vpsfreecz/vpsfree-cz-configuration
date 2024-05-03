{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.log" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 14004;
    host = { name = "log"; location = "int.prg"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.4.1"; prefix = 32; } ];
    };
    logging.isLogger = true;
    services = {
      rsyslog-tcp = {};
      rsyslog-udp = {};
      node-exporter = {};
      syslog-exporter = {};
    };
    tags = [ "auto-update" ];

    healthChecks = {
      systemd.unitProperties = {
        "syslog.service" = [
          { property = "ActiveState"; value = "active"; }
        ];

        "prometheus-syslog-exporter.service" = [
          { property = "ActiveState"; value = "active"; }
        ];
      };
    };
  };
}
