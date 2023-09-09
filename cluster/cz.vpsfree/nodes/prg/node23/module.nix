{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.33"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.251.10"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:2:3::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.252.30"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:1:08::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node23" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-23.06" ];

    node = {
      id = 124;
      role = "hypervisor";
      storageType = "ssd";
    };

    host = {
      name = "node23";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "f4:02:70:d9:6b:8e"
        "f4:02:70:d9:6b:8f"
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
            teng0 = "68:05:ca:b1:c6:e4";
            teng1 = "68:05:ca:b1:c6:e5";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001003;
          routerId = "172.16.0.28";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.251.9"; as = 4200001901; }
              { address = "172.16.252.29"; as = 4200001998; }
            ];
            v6 = [
              { address = "2a03:3b40:42:2:03::1"; as = 4200001901; }
              { address = "2a03:3b40:42:1:08::1"; as = 4200001998; }
            ];
          };
        };

        virtIP = addresses.primary;
      };
    };

    services = {
      ipmi-exporter = {};
      node-exporter = {};
      osctl-exporter = {};
      vpsadmin-console = {};
    };
  };
}
