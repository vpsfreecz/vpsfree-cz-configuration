{ config, lib, ... }:
{
  cluster."cz.vpsfree".pgnd = {
    node1 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.2.10"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };
  };
}
