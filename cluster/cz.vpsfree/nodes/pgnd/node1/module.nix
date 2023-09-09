{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.2.10"; prefix = 32; };
    teng0 = {
      v4 = [
        { address = "172.16.251.46"; prefix = 30; }
      ];
      v6 = [
        { address = "2a03:3b40:42:2:12::2"; prefix = 80; }
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
  cluster."cz.vpsfree/nodes/pgnd/node1" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-23.06" ];

    node = {
      id = 300;
      role = "hypervisor";
      storageType = "ssd";
    };

    host = {
      name = "node1";
      location = "pgnd";
      domain = "vpsfree.cz";
    };

    tags = [ "playground" ];

    netboot = {
      enable = true;
      macs = [
        "b8:ca:3a:6f:bd:24"
        "b8:ca:3a:6f:bd:25"
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
            teng0 = "b8:ca:3a:6f:bd:22";
            teng1 = "b8:ca:3a:6f:bd:20";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001012;
          routerId = "172.16.2.10";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.251.45"; as = 4200001901; }
              { address = "172.16.252.65"; as = 4200001998; }
            ];
            v6 = [
              { address = "2a03:3b40:42:2:12::1"; as = 4200001901; }
              { address = "2a03:3b40:42:1:17::1"; as = 4200001998; }
            ];
          };
        };

        virtIP = addresses.primary;
      };
    };

    services = {
      ipmi-exporter = {};
      node-exporter = {};
      osctl-exporter = {};
      vpsadmin-console = {};
    };
  };
}
