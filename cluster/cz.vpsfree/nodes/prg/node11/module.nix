{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.21"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.253.78"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:0:20::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.252.78"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:1:20::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node11" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-22.01" ];

    node = {
      id = 112;
      role = "hypervisor";
    };

    host = {
      name = "node11";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "00:25:90:fc:3f:2c"
        "00:25:90:fc:3f:2d"
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
            teng0 = "0c:c4:7a:bd:61:0c";
            teng1 = "0c:c4:7a:bd:61:0d";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200000020;
          routerId = "172.16.0.21";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.77"; as = 4200000901; }
              { address = "172.16.252.77"; as = 4200000902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:20::1"; as = 4200000901; }
              { address = "2a03:3b40:42:1:20::1"; as = 4200000902; }
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
