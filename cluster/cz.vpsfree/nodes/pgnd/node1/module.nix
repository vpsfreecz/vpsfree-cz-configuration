{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.2.10"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.253.38"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:0:10::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.252.38"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:1:10::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/pgnd/node1" = rec {
    spin = "vpsadminos";

    node = {
      id = 300;
      role = "hypervisor";
    };

    host = {
      name = "node1";
      location = "pgnd";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "0c:c4:7a:3c:1a:64"
        "0c:c4:7a:3c:1a:65"
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
            teng0 = "a0:36:9f:13:ea:bc";
            teng1 = "a0:36:9f:13:ea:be";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200000010;
          routerId = "172.16.2.10";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.37"; as = 4200000901; }
              { address = "172.16.252.37"; as = 4200000902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:10::1"; as = 4200000901; }
              { address = "2a03:3b40:42:1:10::1"; as = 4200000902; }
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
