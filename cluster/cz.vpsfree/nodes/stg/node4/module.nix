{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.68"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.251.34"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:2:09::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.250.34"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:3:09::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree".stg.node4 = rec {
    type = "node";
    spin = "vpsadminos";

    node = {
      id = 403;
      role = "hypervisor";
    };

    netboot.enable = false;

    addresses = with allAddresses; {
      inherit primary;
      v4 = teng0.v4 ++ teng1.v4;
      v6 = teng0.v6 ++ teng1.v6;
    };

    osNode = {
      networking = {
        interfaces = {
          names = {
            teng0 = "90:b1:1c:1c:d9:29";
            teng1 = "90:b1:1c:1c:d9:27";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001009;
          routerId = "172.16.0.68";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.251.33"; as = 4200001901; }
              { address = "172.16.250.33"; as = 4200001902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:2:09::1"; as = 4200001901; }
              { address = "2a03:3b40:42:3:09::1"; as = 4200001902; }
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
