{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.26"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.251.2"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:2:01::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.250.2"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:3:01::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node16" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod21_03" ];

    node = {
      id = 117;
      role = "hypervisor";
    };

    host = {
      name = "node16";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "0c:c4:7a:30:76:18"
        "0c:c4:7a:30:76:19"
        "0c:c4:7a:30:76:1a"
        "0c:c4:7a:30:76:1b"
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
            teng0 = "0c:c4:7a:88:69:d8";
            teng1 = "0c:c4:7a:88:69:d9";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001001;
          routerId = "172.16.0.26";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.251.1"; as = 4200001901; }
              { address = "172.16.250.1"; as = 4200001902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:2:01::1"; as = 4200001901; }
              { address = "2a03:3b40:42:3:01::1"; as = 4200001902; }
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
