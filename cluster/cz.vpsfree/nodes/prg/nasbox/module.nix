{ config, ... }:
{
  cluster."cz.vpsfree".prg.nasbox = rec {
    type = "node";
    spin = "vpsadminos";

    node = {
      id = 170;
      role = "storage";
    };

    netboot = {
      # TODO: enable when ready
      enable = false;
      macs = [
        "00:25:90:94:3e:bc"
        "00:25:90:94:3e:bd"
        "00:25:90:94:3e:be"
        "00:25:90:94:3e:bf"
      ];
    };

    addresses.primary = { address = "172.16.0.6"; prefix = 23; };

    osNode = {
      networking = {
        interfaces = {
          names = {
            oneg0 = "00:25:90:94:3e:bc";
            oneg1 = "00:25:90:94:3e:bd";
            oneg2 = "00:25:90:94:3e:be";
            oneg3 = "00:25:90:94:3e:bf";
            teng0 = "00:25:90:0e:5a:66";
            teng1 = "00:25:90:0e:5a:67";
          };
        };

        bird = {
          enable = false; # don't need bird as long as bonding is in use
        };

        virtIP = null;
      };
    };

    services = {
      node-exporter = {};
    };
  };
}
