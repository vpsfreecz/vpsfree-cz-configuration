{ config, ... }:
let
  allAddresses = {
    primary = {
      address = "172.16.0.8";
      prefix = 32;
    };
    teng0 = {
      v4 = [
        {
          address = "172.16.253.50";
          prefix = 30;
        }
      ];
      v6 = [
        {
          address = "2a03:3b40:42:0:13::2";
          prefix = 80;
        }
      ];
    };
    teng1 = {
      v4 = [
        {
          address = "172.16.252.50";
          prefix = 30;
        }
      ];
      v6 = [
        {
          address = "2a03:3b40:42:1:13::2";
          prefix = 80;
        }
      ];
    };
  };
in
{
  cluster."cz.vpsfree/nodes/prg/backuper2" = rec {
    spin = "vpsadminos";

    pins.channels = [ "production" ];

    node = {
      id = 161;
      role = "storage";
      storageType = "hdd";
    };

    host = {
      name = "backuper2";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "0c:c4:7a:14:0c:e8"
        "0c:c4:7a:14:0c:e9"
        "0c:c4:7a:14:0c:ea"
        "0c:c4:7a:14:0c:eb"
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
            oneg0 = "0c:c4:7a:14:0c:e8";
            oneg1 = "0c:c4:7a:14:0c:e9";
            oneg2 = "0c:c4:7a:14:0c:ea";
            oneg3 = "0c:c4:7a:14:0c:eb";
            teng0 = "94:40:c9:ae:97:90";
            teng1 = "94:40:c9:ae:97:91";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001001;
          routerId = "172.16.0.8";
          bgpNeighbours = {
            v4 = [
              {
                address = "172.16.253.49";
                as = 4200001999;
              }
              {
                address = "172.16.252.49";
                as = 4200001998;
              }
            ];
            v6 = [
              {
                address = "2a03:3b40:42:0:13::1";
                as = 4200001999;
              }
              {
                address = "2a03:3b40:42:1:13::1";
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
    };
  };
}
