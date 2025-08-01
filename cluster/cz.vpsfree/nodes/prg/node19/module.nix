{ config, ... }:
let
  allAddresses = {
    primary = {
      address = "172.16.0.29";
      prefix = 32;
    };
    teng0 = {
      v4 = [
        {
          address = "172.16.253.54";
          prefix = 30;
        }
      ];
      v6 = [
        {
          address = "2a03:3b40:42:0:14::2";
          prefix = 80;
        }
      ];
    };
    teng1 = {
      v4 = [
        {
          address = "172.16.252.54";
          prefix = 30;
        }
      ];
      v6 = [
        {
          address = "2a03:3b40:42:1:14::2";
          prefix = 80;
        }
      ];
    };
  };
in
{
  cluster."cz.vpsfree/nodes/prg/node19" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "production" ];

    node = {
      id = 120;
      role = "hypervisor";
      storageType = "ssd";
    };

    host = {
      name = "node19";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "b0:7b:25:bf:12:8a"
        "b0:7b:25:bf:12:8b"
      ];
    };

    addresses = with allAddresses; {
      inherit primary;
      v4 = teng0.v4 ++ teng1.v4;
      v6 = teng0.v6 ++ teng1.v6;
    };

    osNode = {
      networking = {
        interfaces = {
          names = {
            teng0 = "0c:42:a1:91:78:a6";
            teng1 = "0c:42:a1:91:78:a7";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001005;
          routerId = "172.16.0.29";
          bgpNeighbours = {
            v4 = [
              {
                address = "172.16.253.53";
                as = 4200001999;
              }
              {
                address = "172.16.252.53";
                as = 4200001998;
              }
            ];
            v6 = [
              {
                address = "2a03:3b40:42:0:14::1";
                as = 4200001999;
              }
              {
                address = "2a03:3b40:42:1:14::1";
                as = 4200001998;
              }
            ];
          };
        };

        virtIP = addresses.primary;
      };
    };

    services = {
      goresheat = { };
      ipmi-exporter = { };
      ksvcmon-exporter = { };
      node-exporter = { };
      osctl-exporter = { };
      vpsadmin-console = { };
    };
  };
}
