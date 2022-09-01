{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.19"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.253.66"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:0:17::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.252.66"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:1:17::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node9" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-22.09" ];

    node = {
      id = 110;
      role = "hypervisor";
    };

    host = {
      name = "node9";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "00:25:90:e6:61:82"
        "00:25:90:e6:61:83"
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
            teng0 = "0c:c4:7a:88:69:f8";
            teng1 = "0c:c4:7a:88:69:f9";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200000017;
          routerId = "172.16.0.19";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.65"; as = 4200000901; }
              { address = "172.16.252.65"; as = 4200000902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:17::1"; as = 4200000901; }
              { address = "2a03:3b40:42:1:17::1"; as = 4200000902; }
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
