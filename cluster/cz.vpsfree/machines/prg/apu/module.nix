{ config, ... }:
{
  cluster."cz.vpsfree/machines/prg/apu" = rec {
    spin = "nixos";

    pins.channels = [ "nixos-stable" ];

    host = {
      name = "apu";
      location = "int.prg";
      domain = "vpsfree.cz";
      target = "172.16.254.254";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.254.254";
          prefix = 24;
        }
      ];
    };

    tags = [
      "apu"
      "vpsf-status"
      "pxe-server"
    ];

    services = {
      node-exporter = { };
      sachet = { };
    };

    carrier = {
      enable = true;

      machines = import ../../../../../lib/netboot-machines.nix {
        inherit (config) cluster;

        tags = [
          "pxe"
          "pxe-secondary"
        ];

        dynamicTags = [ "pxe" ];

        buildGenerations = {
          min = 5;
          max = 10;
          maxAge = 180 * 24 * 60 * 60;
        };

        hostGenerations = {
          min = 20;
          max = 40;
          maxAge = 360 * 24 * 60 * 60;
        };
      };
    };

    healthChecks = {
      systemd.unitProperties = {
        "netboot-atftpd.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "sachet.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "vpsf-status.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];
      };
    };
  };
}
