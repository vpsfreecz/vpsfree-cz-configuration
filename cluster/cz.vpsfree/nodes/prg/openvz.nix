{ config, lib, ... }:
{
  cluster = {
    "cz.vpsfree/nodes/prg/node2" = {
      spin = "openvz";
      node = {
        id = 102;
        role = "hypervisor";
      };
      host = {
        name = "node2";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.11"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node3" = {
      spin = "openvz";
      node = {
        id = 103;
        role = "hypervisor";
      };
      host = {
        name = "node3";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.12"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node4" = {
      spin = "openvz";
      node = {
        id = 104;
        role = "hypervisor";
      };
      host = {
        name = "node4";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.13"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node5" = {
      spin = "openvz";
      node = {
        id = 105;
        role = "hypervisor";
      };
      host = {
        name = "node5";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.14"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node6" = {
      spin = "openvz";
      node = {
        id = 106;
        role = "hypervisor";
      };
      host = {
        name = "node6";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.15"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node12" = {
      spin = "openvz";
      node = {
        id = 113;
        role = "hypervisor";
      };
      host = {
        name = "node12";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.22"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node14" = {
      spin = "openvz";
      node = {
        id = 115;
        role = "hypervisor";
      };
      host = {
        name = "node14";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.24"; prefix = 23; };
      vzNode.role = "hypervisor";
      monitoring.enable = false;
      services.node-exporter = {};
    };
  };
}
