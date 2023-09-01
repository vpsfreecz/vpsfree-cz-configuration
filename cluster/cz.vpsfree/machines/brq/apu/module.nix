{ config, ... }:
{
  cluster."cz.vpsfree/machines/brq/apu" = rec {
    spin = "nixos";

    # os-staging is needed to keep the channels same with the build machine, so
    # that confctl can evaluate it in one run when deploying all pxe machines.
    swpins.channels = [ "nixos-stable" "os-staging" ];

    host = { name = "apu"; location = "int.brq"; domain = "vpsfree.cz"; target = "172.19.254.254"; };
    addresses = {
      v4 = [ { address = "172.19.254.254"; prefix = 24; } ];
    };

    tags = [ "apu" "pxe" "pxe-secondary" ];

    services = {
      node-exporter = {};
      sachet = {};
    };

    healthChecks = {
      systemd.unitProperties = {
        "netboot-atftpd.service" = [
          { property = "ActiveState"; value = "active"; }
        ];

        "sachet.service" = [
          { property = "ActiveState"; value = "active"; }
        ];
      };
    };

    buildGenerations = {
      min = 5;
      max = 10;
      maxAge = 180*24*60*60;
    };

    hostGenerations = {
      min = 20;
      max = 40;
      maxAge = 360*24*60*60;
    };
  };
}
