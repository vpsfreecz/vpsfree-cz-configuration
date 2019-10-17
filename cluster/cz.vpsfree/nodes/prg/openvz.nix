{ config, lib, ... }:
{
  cluster."cz.vpsfree".prg = {
    node2 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.11"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node3 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.12"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node4 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.13"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node5 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.14"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node6 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.15"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node7 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.17"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node8 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.18"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node9 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.19"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node10 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.20"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node11 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.21"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node12 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.22"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node13 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.23"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node14 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.24"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node15 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.25"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node17 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.27"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node18 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = { address = "172.16.0.28"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };
  };
}
