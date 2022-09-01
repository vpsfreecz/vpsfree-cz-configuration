{ config, ... }:
{
  cluster."cz.vpsfree/nodes/brq/node4" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-22.09" ];

    node = {
      id = 213;
      role = "hypervisor";
    };

    host = {
      name = "node4";
      location = "brq";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "b8:ca:3a:6f:ba:3c"
        "b8:ca:3a:6f:ba:3d"
      ];
    };

    addresses = {
      primary = { address = "172.19.0.13"; prefix = 23; };
    };

    osNode = {
      networking = {
        interfaces = {
          names = {
            oneg0 = "b8:ca:3a:6f:ba:3c";
            oneg1 = "b8:ca:3a:6f:ba:3d";

            teng0 = "b8:ca:3a:6f:ba:38";
            teng1 = "b8:ca:3a:6f:ba:3a";
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
      node-exporter = {};
      osctl-exporter = {};
      vpsadmin-console = {};
    };
  };
}
