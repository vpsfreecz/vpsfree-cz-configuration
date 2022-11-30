{ config, lib, ... }:
{
  cluster = {
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
  };
}
