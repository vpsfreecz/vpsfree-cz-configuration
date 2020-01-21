{ config, ... }:
let
  allAddresses = {
    primary = { address = "172.16.0.5"; prefix = 32; };
    teng0 = {
      v4 = [ { address = "172.16.251.182"; prefix = 30; } ];
      v6 = [ { address = "2a03:3b40:42:2:46::2"; prefix = 80; } ];
    };
    teng1 = {
      v4 = [ { address = "172.16.250.182"; prefix = 30; } ];
      v6 = [ { address = "2a03:3b40:42:3:46::2"; prefix = 80; } ];
    };
  };
in {
  cluster."cz.vpsfree".prg.backuper = rec {
    type = "node";
    spin = "vpsadminos";

    node = {
      id = 160;
      role = "storage";
    };

    netboot = {
      enable = true;
      macs = [
        "00:25:90:2f:a3:ac"
        "00:25:90:2f:a3:ad"
        "00:25:90:2f:a3:ae"
        "00:25:90:2f:a3:af"
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
            oneg0 = "00:25:90:2f:a3:ac";
            oneg1 = "00:25:90:2f:a3:ad";
            oneg2 = "00:25:90:2f:a3:ae";
            oneg3 = "00:25:90:2f:a3:af";
            teng0 = "00:25:90:0e:5b:1a";
            teng1 = "00:25:90:0e:5b:1b";
          };
          addresses = {
            inherit (allAddresses) teng0 teng1;
          };
        };

        bird = {
          as = 4200001046;
          routerId = "172.16.0.5";
          bgpNeighbours = {
            v4 = [
              { address = "172.16.251.181"; as = 4200001901; }
              { address = "172.16.250.181"; as = 4200001902; }
            ];
            v6 = [
              { address = "2a03:3b40:42:2:46::1"; as = 4200001901; }
              { address = "2a03:3b40:42:3:46::1"; as = 4200001902; }
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
