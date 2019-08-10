{ config, lib, ... }:
{
  cluster."vpsfree.cz".pgnd = {
    node1 = {
      addresses.main = "172.16.2.10";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };
  };
}
