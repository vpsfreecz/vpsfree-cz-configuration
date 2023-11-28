{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.api1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "vpsadmin" ];
    container.id = 20273;
    host = { name = "api1"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.128"; prefix = 32; } ];
    };
    services.node-exporter = {};
    tags = [ "vpsadmin" "api" "auto-update" ];

    healthChecks = {
      systemd.unitProperties = {
        "vpsadmin-api.service" = [
          { property = "ActiveState"; value = "active"; }
        ];

        "vpsadmin-scheduler.service" = [
          { property = "ActiveState"; value = "active"; }
        ];

        "vpsadmin-supervisor.service" = [
          { property = "ActiveState"; value = "active"; }
        ];

        "vpsadmin-console-router.service" = [
          { property = "ActiveState"; value = "active"; }
        ];
      };
    };
  };
}
