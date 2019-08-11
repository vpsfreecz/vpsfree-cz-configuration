{ config, lib, ... }:
{
  cluster."vpsfree.cz".pgnd = {
    node1 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.2.10";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };
  };
}
