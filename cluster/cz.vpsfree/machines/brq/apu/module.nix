{ config, ... }:
{
  cluster."cz.vpsfree/machines/brq/apu" = rec {
    spin = "nixos";

    swpins.channels = [ "nixos-stable" ];

    host = {
      name = "apu";
      location = "int.brq";
      domain = "vpsfree.cz";
      target = "172.19.254.254";
    };
    addresses = {
      v4 = [
        {
          address = "172.19.254.254";
          prefix = 24;
        }
      ];
    };

    tags = [
      "apu"
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

        dynamicTags = [
          "brq"
          "pxe"
        ];

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
      };
    };
  };
}
