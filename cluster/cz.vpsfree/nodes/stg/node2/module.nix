{ config, ... }:
let
  allAddresses = {
    primary = {
      address = "172.16.0.67";
      prefix = 32;
    };
    teng0 = {
      v4 = [
        {
          address = "172.16.253.58";
          prefix = 30;
        }
      ];
      v6 = [
        {
          address = "2a03:3b40:42:0:15::2";
          prefix = 80;
        }
      ];
    };
    teng1 = {
      v4 = [
        {
          address = "172.16.252.58";
          prefix = 30;
        }
      ];
      v6 = [
        {
          address = "2a03:3b40:42:1:15::2";
          prefix = 80;
        }
      ];
    };
  };
in
{
  cluster."cz.vpsfree/nodes/stg/node2" = rec {
    spin = "vpsadminos";

    inputs.channels = [ "staging" ];

    node = {
      id = 401;
      role = "hypervisor";
      storageType = "ssd";
    };

    host = {
      name = "node2";
      location = "stg";
      domain = "vpsfree.cz";
    };

    tags = [ "staging" ];

    netboot = {
      enable = true;
      macs = [
        "24:6e:96:0f:27:25"
        "24:6e:96:0f:27:24"
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
            teng0 = "a0:36:9f:4e:60:08";
            teng1 = "a0:36:9f:4e:60:0a";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001007;
          routerId = "172.16.0.67";
          bgpNeighbours = {
            v4 = [
              {
                address = "172.16.253.57";
                as = 4200001999;
              }
              {
                address = "172.16.252.57";
                as = 4200001998;
              }
            ];
            v6 = [
              {
                address = "2a03:3b40:42:0:15::1";
                as = 4200001999;
              }
              {
                address = "2a03:3b40:42:1:15::1";
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
      ebpf-exporter = { };
      ipmi-exporter = { };
      ksvcmon-exporter = { };
      node-exporter = { };
      osctl-exporter = { };
      zfs-exporter = { };
      vpsadmin-console = { };
    };
  };
}
