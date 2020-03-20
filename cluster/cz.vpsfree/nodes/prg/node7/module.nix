{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.17"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.253.30"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:0:8::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.252.30"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:1:8::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree".prg.node7 = rec {
    type = "node";
    spin = "vpsadminos";

    node = {
      id = 108;
      role = "hypervisor";
    };

    netboot = {
      enable = true;
      macs = [
        "00:25:90:91:d3:96"
        "00:25:90:91:d3:97"
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
            teng0 = "0c:c4:7a:88:6a:74";
            teng1 = "0c:c4:7a:88:6a:75";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200000008;
          routerId = "172.16.0.17";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.29"; as = 4200000901; }
              { address = "172.16.252.29"; as = 4200000902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:08::1"; as = 4200000901; }
              { address = "2a03:3b40:42:1:08::1"; as = 4200000902; }
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
