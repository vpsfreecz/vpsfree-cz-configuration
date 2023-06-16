{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.mon1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 14005;
    host = { name = "mon1"; location = "int.prg"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.4.10"; prefix = 32; } ];
    };
    services = {
      node-exporter = {};
      prometheus = {};
    };
    monitoring.isMonitor = true;
    tags = [ "monitor" "auto-update" ];

    healthChecks = {
      systemd.unitProperties = {
        "prometheus.service" = [
          { property = "ActiveState"; value = "active"; }
        ];
      };
    };
  };
}
