{ config, lib, ... }:
{
  cluster."vpsfree.cz".brq = {
    node1 = {
      addresses.primary = "172.19.0.10";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node2 = {
      addresses.primary = "172.19.0.11";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node3 = {
      addresses.primary = "172.19.0.12";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node4 = {
      addresses.primary = "172.19.0.13";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };
  };
}
