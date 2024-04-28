{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.31"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.253.22"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:0:06::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.252.22"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:1:06::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node21" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-24.01" ];

    node = {
      id = 122;
      role = "hypervisor";
      storageType = "ssd";
    };

    host = {
      name = "node21";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "44:a8:42:27:c4:d0"
        "44:a8:42:27:c4:d1"
        "44:a8:42:27:c4:d2"
        "44:a8:42:27:c4:d3"
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
            teng0 = "a0:36:9f:61:d1:a0";
            teng1 = "a0:36:9f:61:d1:a2";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001010;
          routerId = "172.16.0.31";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.21"; as = 4200001999; }
              { address = "172.16.252.21"; as = 4200001998; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:06::1"; as = 4200001999; }
              { address = "2a03:3b40:42:1:06::1"; as = 4200001998; }
            ];
          };
        };

        virtIP = addresses.primary;
      };
    };

    services = {
      ipmi-exporter = {};
      ksvcmon-exporter = {};
      node-exporter = {};
      osctl-exporter = {};
      vpsadmin-console = {};
    };
  };
}
