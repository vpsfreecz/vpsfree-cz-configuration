{ config, ... }:
{
  cluster."cz.vpsfree/machines/build" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    host = { name = "build"; domain = "vpsfree.cz"; target = "172.16.106.5"; };
    addresses = {
      v4 = [ { address = "172.16.106.5"; prefix = 24; } ];
    };
    tags = [ "build" "pxe" "pxe-primary" ];
    services.node-exporter = {};

    healthChecks = {
      systemd.unitProperties = {
        "netboot-atftpd.service" = [
          { property = "ActiveState"; value = "active"; }
        ];
      };
    };

    buildGenerations = {
      min = 10;
      max = 20;
      maxAge = 180*24*60*60;
    };

    hostGenerations = {
      min = 30;
      max = 40;
      maxAge = 360*24*60*60;
    };
  };
}
