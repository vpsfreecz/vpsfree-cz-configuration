{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.29"; prefix = 32; };
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
  cluster."cz.vpsfree/nodes/prg/node19" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod21_03" ];

    node = {
      id = 120;
      role = "hypervisor";
    };

    host = {
      name = "node19";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "ec:f4:bb:cf:f3:3c"
        "ec:f4:bb:cf:f3:3d"
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
            teng0 = "ec:f4:bb:cf:f3:38";
            teng1 = "ec:f4:bb:cf:f3:3a";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001009;
          routerId = "172.16.0.29";
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
