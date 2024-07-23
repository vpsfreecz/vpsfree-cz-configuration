{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.32"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.253.26"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:0:07::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.252.26"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:1:07::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node22" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-24.07" ];

    node = {
      id = 123;
      role = "hypervisor";
      storageType = "ssd";
    };

    host = {
      name = "node22";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "2c:ea:7f:f7:c6:e6"
        "2c:ea:7f:f7:c6:e7"
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
            teng0 = "a0:36:9f:93:72:12";
            teng1 = "a0:36:9f:93:72:10";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001013;
          routerId = "172.16.0.32";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.25"; as = 4200001999; }
              { address = "172.16.252.25"; as = 4200001998; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:07::1"; as = 4200001999; }
              { address = "2a03:3b40:42:1:07::1"; as = 4200001998; }
            ];
          };
        };

        virtIP = addresses.primary;
      };
    };

    services = {
      goresheat = {};
      ipmi-exporter = {};
      ksvcmon-exporter = {};
      node-exporter = {};
      osctl-exporter = {};
      vpsadmin-console = {};
    };
  };
}
