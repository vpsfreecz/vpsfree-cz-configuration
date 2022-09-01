{ config, ... }:
{
  cluster."cz.vpsfree/nodes/brq/node2" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "prod-22.09" ];

    node = {
      id = 211;
      role = "hypervisor";
    };

    host = {
      name = "node2";
      location = "brq";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "00:25:90:c9:cf:c4"
        "00:25:90:c9:cf:c5"
      ];
    };

    addresses = {
      primary = { address = "172.19.0.11"; prefix = 23; };
    };

    osNode = {
      networking = {
        interfaces = {
          names = {
            oneg0 = "00:25:90:c9:cf:c4";
            oneg1 = "00:25:90:c9:cf:c5";

            teng0 = "3c:ec:ef:38:4d:60";
            teng1 = "3c:ec:ef:38:4d:61";
          };
        };

        bird = {
          routerId = "172.19.0.11";
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
