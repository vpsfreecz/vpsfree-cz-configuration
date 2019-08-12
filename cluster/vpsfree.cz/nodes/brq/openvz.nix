{ config, lib, ... }:
{
  cluster."vpsfree.cz".brq = {
    node1 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.19.0.10"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node2 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.19.0.11"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node3 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.19.0.12"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node4 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.19.0.13"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };
  };
}
