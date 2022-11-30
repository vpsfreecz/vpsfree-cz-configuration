{ config, lib, ... }:
{
  cluster = {
    "cz.vpsfree/nodes/brq/node3" = {
      spin = "openvz";
      node = {
        id = 212;
        role = "hypervisor";
      };
      host = {
        name = "node3";
        location = "brq";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.19.0.12"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };
  };
}
