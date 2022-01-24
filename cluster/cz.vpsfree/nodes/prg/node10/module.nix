{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.20"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.253.62"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:0:16::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.252.62"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:1:16::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node10" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-22.01" ];

    node = {
      id = 111;
      role = "hypervisor";
    };

    host = {
      name = "node10";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "0c:c4:7a:30:73:90"
        "0c:c4:7a:30:73:91"
        "0c:c4:7a:30:73:92"
        "0c:c4:7a:30:73:93"
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
            teng0 = "0c:c4:7a:88:69:f2";
            teng1 = "0c:c4:7a:88:69:f3";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200000016;
          routerId = "172.16.0.20";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.61"; as = 4200000901; }
              { address = "172.16.252.61"; as = 4200000902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:16::1"; as = 4200000901; }
              { address = "2a03:3b40:42:1:16::1"; as = 4200000902; }
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
