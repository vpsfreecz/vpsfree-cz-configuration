{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.28"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.251.10"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:2:3::2"; prefix = 80; }
      ];
    };
    teng1 = {
      v4 = [
        { address = "172.16.250.10"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:3:3::2"; prefix = 80; }
      ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/node18" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-22.09" ];

    node = {
      id = 119;
      role = "hypervisor";
    };

    host = {
      name = "node18";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "b8:ca:3a:6f:b8:4c"
        "b8:ca:3a:6f:b8:4d"
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
            teng0 = "b8:ca:3a:6f:b8:48";
            teng1 = "b8:ca:3a:6f:b8:4a";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001003;
          routerId = "172.16.0.28";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.251.9"; as = 4200001901; }
              { address = "172.16.250.9"; as = 4200001902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:2:03::1"; as = 4200001901; }
              { address = "2a03:3b40:42:3:03::1"; as = 4200001902; }
            ];
          };
        };

        virtIP = addresses.primary;
      };
    };

    monitoring.enable = false;

    services = {
      node-exporter = {};
      osctl-exporter = {};
      vpsadmin-console = {};
    };
  };
}
