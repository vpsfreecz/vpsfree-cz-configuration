{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.18"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.253.46"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:0:12::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.252.46"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:1:12::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node8" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod21_03" ];

    node = {
      id = 109;
      role = "hypervisor";
    };

    host = {
      name = "node8";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "00:25:90:91:d5:06"
        "00:25:90:91:d5:07"
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
            teng0 = "0c:c4:7a:88:69:fa";
            teng1 = "0c:c4:7a:88:69:fb";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200000012;
          routerId = "172.16.0.18";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.45"; as = 4200000901; }
              { address = "172.16.252.45"; as = 4200000902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:12::1"; as = 4200000901; }
              { address = "2a03:3b40:42:1:12::1"; as = 4200000902; }
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
