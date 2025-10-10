{ config, confData, ... }:
{
  cluster."cz.vpsfree/nodes/brq/node5" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "production" ];

    node = {
      id = 214;
      role = "hypervisor";
      storageType = "ssd";
    };

    host = {
      name = "node5";
      location = "brq";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "3c:ec:ef:73:88:04"
        "3c:ec:ef:73:88:05"
      ];
    };

    addresses = {
      primary = {
        address = "172.19.0.14";
        prefix = 23;
      };
    };

    osNode = {
      networking = {
        interfaces = {
          names = {
            teng0 = "3c:ec:ef:73:88:04";
            teng1 = "3c:ec:ef:73:88:05";
          };
        };

        bird = {
          routerId = "172.19.0.14";
          routingProtocol = "ospf";
        };

        virtIP = null;
      };
    };

    services = {
      goresheat = { };
      ipmi-exporter = { };
      ksvcmon-exporter = { };
      node-exporter = { };
      osctl-exporter = { };
      vpsadmin-console = { };
    };
  };
}
