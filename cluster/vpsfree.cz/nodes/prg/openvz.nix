{ config, lib, ... }:
{
  cluster."vpsfree.cz".prg = {
    node2 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.11";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node3 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.12";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node4 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.13";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node5 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.14";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node6 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.15";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node7 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.17";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node8 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.18";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node9 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.19";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node10 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.20";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node11 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.21";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node12 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.22";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node13 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.23";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node14 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.24";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node15 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.25";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node17 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.27";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node18 = {
      type = "node";
      spin = "openvz";
      node.role = "hypervisor";
      addresses.primary = "172.16.0.28";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    nasbox = {
      type = "node";
      spin = "openvz";
      node.role = "storage";
      addresses.primary = "172.16.0.6";
      vzNode.role = "storage";
      services.node-exporter = {};
    };
  };
}
