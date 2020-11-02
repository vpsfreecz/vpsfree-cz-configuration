{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.10"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.253.42"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:0:11::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.252.42"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:1:11::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node1" = rec {
    spin = "vpsadminos";

    node = {
      id = 101;
      role = "hypervisor";
    };

    host = {
      name = "node1";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "00:25:90:4f:1c:0c"
        "00:25:90:4f:1c:0d"
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
            teng0 = "0c:c4:7a:88:6a:66";
            teng1 = "0c:c4:7a:88:6a:67";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200000011;
          routerId = "172.16.0.10";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.41"; as = 4200000901; }
              { address = "172.16.252.41"; as = 4200000902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:11::1"; as = 4200000901; }
              { address = "2a03:3b40:42:1:11::1"; as = 4200000902; }
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
