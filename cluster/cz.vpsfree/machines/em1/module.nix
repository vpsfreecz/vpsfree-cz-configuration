{ config, ... }:
{
  cluster."cz.vpsfree/machines/em1" = rec {
    spin = "nixos";

    pins.channels = [ "nixos-stable" ];

    host = {
      name = "em1";
      domain = "vpsfree.cz";
    };

    addresses = {
      v4 = [
        {
          address = "49.12.231.200";
          prefix = 24;
        }
      ];
      v6 = [
        {
          address = "2a01:4f8:1c1a:7604::1";
          prefix = 64;
        }
      ];
    };

    tags = [
      "em"
    ];

    services = {
      node-exporter = { };
    };

    monitoring.target = "172.31.0.34";
  };
}
