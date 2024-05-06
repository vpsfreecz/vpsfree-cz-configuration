{ config, ... }:
{
  cluster."cz.vpsfree/machines/build" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    host = { name = "build"; domain = "vpsfree.cz"; target = "172.16.106.5"; };
    addresses = {
      v4 = [ { address = "172.16.106.5"; prefix = 24; } ];
    };
    tags = [ "build" ];

    services = {
      node-exporter = {};
      ssh-exporter = {};
    };

    carrier = {
      enable = true;
      machines = import ../../../../lib/netboot-machines.nix {
        inherit (config) cluster;

        tags = [ "pxe" "pxe-primary" ];

        buildGenerations = {
          min = 10;
          max = 20;
          maxAge = 180*24*60*60;
        };

        hostGenerations = {
          min = 20;
          max = 30;
          maxAge = 360*24*60*60;
        };
      };
    };

    healthChecks = {
      systemd.unitProperties = {
        "netboot-atftpd.service" = [
          { property = "ActiveState"; value = "active"; }
        ];
      };
    };
  };
}
