{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.23"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.253.54"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:0:14::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.252.54"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:1:14::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node13" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "production" ];

    node = {
      id = 114;
      role = "hypervisor";
    };

    host = {
      name = "node13";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "00:25:90:98:63:fa"
        "00:25:90:98:63:fb"
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
            teng0 = "0c:c4:7a:88:69:de";
            teng1 = "0c:c4:7a:88:69:df";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200000014;
          routerId = "172.16.0.23";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.53"; as = 4200000901; }
              { address = "172.16.252.53"; as = 4200000902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:14::1"; as = 4200000901; }
              { address = "2a03:3b40:42:1:14::1"; as = 4200000902; }
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
