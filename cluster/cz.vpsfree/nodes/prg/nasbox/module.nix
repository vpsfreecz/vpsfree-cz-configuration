{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.6"; prefix = 32; };
    teng0 = {
      v4 = [ { address = "172.16.251.26"; prefix = 30; } ];
      v6 = [ { address = "2a03:3b40:42:2:07::2"; prefix = 80; } ];
    };
    teng1 = {
      v4 = [ { address = "172.16.250.26"; prefix = 30; } ];
      v6 = [ { address = "2a03:3b40:42:3:07::2"; prefix = 80; } ];
    };
  };
in {
  cluster."cz.vpsfree/nodes/prg/nasbox" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-22.09" ];

    node = {
      id = 170;
      role = "storage";
    };

    host = {
      name = "nasbox";
      location = "prg";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "00:25:90:98:63:b6"
        "00:25:90:98:63:b7"
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
            oneg0 = "00:25:90:98:63:b6";
            oneg1 = "00:25:90:98:63:b7";
            teng0 = "00:25:90:0e:5a:66";
            teng1 = "00:25:90:0e:5a:67";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001007;
          routerId = "172.16.0.6";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.251.25"; as = 4200001901; }
              { address = "172.16.250.25"; as = 4200001902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:2:07::1"; as = 4200001901; }
              { address = "2a03:3b40:42:3:07::1"; as = 4200001902; }
            ];
          };
        };

        virtIP = addresses.primary;
      };
    };

    services = {
      node-exporter = {};
      osctl-exporter = {};
    };
  };
}
