{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.30"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.251.30"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:2:08::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.250.30"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:3:08::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node20" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod21_09" ];

    node = {
      id = 121;
      role = "hypervisor";
    };

    host = {
      name = "node20";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "ec:f4:bb:d0:08:f4"
        "ec:f4:bb:d0:08:f5"
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
            teng0 = "ec:f4:bb:d0:08:f2";
            teng1 = "ec:f4:bb:d0:08:f0";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001008;
          routerId = "172.16.0.30";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.251.29"; as = 4200001901; }
              { address = "172.16.250.29"; as = 4200001902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:2:08::1"; as = 4200001901; }
              { address = "2a03:3b40:42:3:08::1"; as = 4200001902; }
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
