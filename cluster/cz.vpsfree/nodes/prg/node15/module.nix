{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.25"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.251.18"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:2:5::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.250.18"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:3:5::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node15" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-22.12" ];

    node = {
      id = 116;
      role = "hypervisor";
      storageType = "hdd";
    };

    host = {
      name = "node15";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "0c:c4:7a:30:62:5c"
        "0c:c4:7a:30:62:5d"
        "0c:c4:7a:30:62:5e"
        "0c:c4:7a:30:62:5f"
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
            teng0 = "a0:36:9f:80:e6:1c";
            teng1 = "a0:36:9f:80:e6:1e";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001005;
          routerId = "172.16.0.25";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.251.17"; as = 4200001901; }
              { address = "172.16.250.17"; as = 4200001902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:2:05::1"; as = 4200001901; }
              { address = "2a03:3b40:42:3:05::1"; as = 4200001902; }
            ];
          };
        };

        virtIP = addresses.primary;
      };
    };

    services = {
      node-exporter = {};
      osctl-exporter = {};
      vpsadmin-console = {};
    };
  };
}
