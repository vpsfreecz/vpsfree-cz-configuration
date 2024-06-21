{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.30"; prefix = 32; };
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
  cluster."cz.vpsfree/nodes/prg/node20" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-24.01" ];

    node = {
      id = 121;
      role = "hypervisor";
      storageType = "ssd";
    };

    host = {
      name = "node20";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "c4:5a:b1:9b:d4:a2"
        "c4:5a:b1:9b:d4:a3"
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
            teng0 = "04:3f:72:fa:a8:14";
            teng1 = "04:3f:72:fa:a8:15";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001006;
          routerId = "172.16.0.30";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.253.41"; as = 4200001999; }
              { address = "172.16.252.41"; as = 4200001998; }
            ];
            v6 = [
              { address = "2a03:3b40:42:0:11::1"; as = 4200001999; }
              { address = "2a03:3b40:42:1:11::1"; as = 4200001998; }
            ];
          };
        };

        virtIP = addresses.primary;
      };
    };

    services = {
      ipmi-exporter = {};
      ksvcmon-exporter = {};
      node-exporter = {};
      osctl-exporter = {};
      vpsadmin-console = {};
    };
  };
}
