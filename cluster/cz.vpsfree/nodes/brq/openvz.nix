{ config, lib, ... }:
{
  cluster = {
    "cz.vpsfree/nodes/brq/node1" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node1";
        location = "brq";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.19.0.10"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/brq/node2" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node2";
        location = "brq";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.19.0.11"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/brq/node3" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node3";
        location = "brq";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.19.0.12"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/brq/node4" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node4";
        location = "brq";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.19.0.13"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };
  };
}
