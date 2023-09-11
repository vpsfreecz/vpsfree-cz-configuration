{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.66"; prefix = 32; };
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
  cluster."cz.vpsfree/nodes/stg/node1" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "staging" ];

    node = {
      id = 400;
      role = "hypervisor";
      storageType = "nvme";
    };

    host = {
      name = "node1";
      location = "stg";
      domain = "vpsfree.cz";
    };

    tags = [ "staging" ];

    netboot = {
      enable = true;
      macs = [
        "0c:c4:7a:ab:b4:43"
        "0c:c4:7a:ab:b4:42"
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
          names= {
            teng0 = "0c:c4:7a:88:70:14";
            teng1 = "0c:c4:7a:88:70:15";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001002;
          routerId = "172.16.0.66";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.61"; as = 4200001999; }
              { address = "172.16.252.61"; as = 4200001998; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:16::1"; as = 4200001999; }
              { address = "2a03:3b40:42:1:16::1"; as = 4200001998; }
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
