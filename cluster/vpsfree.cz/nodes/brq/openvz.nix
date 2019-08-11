{ config, lib, ... }:
{
  cluster."vpsfree.cz".brq = {
    node1 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.19.0.10";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node2 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.19.0.11";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node3 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.19.0.12";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node4 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.19.0.13";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };
  };
}
