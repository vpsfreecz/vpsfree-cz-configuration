{ config, confData, ... }:
{
  cluster."cz.vpsfree/nodes/brq/node6" = rec {
    spin = "vpsadminos";

    swpins.channels = [ "production" ];

    node = {
      id = 215;
      role = "hypervisor";
      storageType = "ssd";
    };

    host = {
      name = "node6";
      location = "brq";
      domain = "vpsfree.cz";
    };

    netboot = {
      enable = true;
      macs = [
        "b0:7b:25:bd:ef:4a"
        "b0:7b:25:bd:ef:4b"
      ];
    };

    addresses = {
      primary = { address = "172.19.0.15"; prefix = 23; };
    };

    osNode = {
      networking = {
        interfaces = {
          names = {
            oneg0 = "b0:7b:25:bd:ef:4a";
            oneg1 = "b0:7b:25:bd:ef:4b";
          };
        };

        bird = {
          routerId = "172.19.0.15";
          routingProtocol = "ospf";
        };

        virtIP = null;
      };
    };

    services = {
      goresheat = {};
      ipmi-exporter = {};
      ksvcmon-exporter = {};
      node-exporter = {};
      osctl-exporter = {};
      vpsadmin-console = {};
    };
  };
}
