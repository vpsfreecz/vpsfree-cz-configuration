{ config, ... }:
{
  cluster."cz.vpsfree/nodes/brq/node4" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-23.06" ];

    node = {
      id = 213;
      role = "hypervisor";
      storageType = "ssd";
    };

    host = {
      name = "node4";
      location = "brq";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "ec:f4:bb:cf:f3:3c"
        "ec:f4:bb:cf:f3:3d"
      ];
    };

    addresses = {
      primary = { address = "172.19.0.13"; prefix = 23; };
    };

    osNode = {
      networking = {
        interfaces = {
          names = {
            oneg0 = "ec:f4:bb:cf:f3:3c";
            oneg1 = "ec:f4:bb:cf:f3:3d";

            teng0 = "ec:f4:bb:cf:f3:38";
            teng1 = "ec:f4:bb:cf:f3:3a";
          };
        };

        bird = {
          routerId = "172.19.0.13";
          routingProtocol = "ospf";
        };

        virtIP = null;
      };
    };

    services = {
      ipmi-exporter = {};
      node-exporter = {};
      osctl-exporter = {};
      vpsadmin-console = {};
    };

    monitoring.enable = false;
  };
}
