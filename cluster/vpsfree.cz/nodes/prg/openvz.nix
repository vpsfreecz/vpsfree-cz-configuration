{ config, lib, ... }:
{
  cluster."vpsfree.cz".prg = {
    node2 = {
      addresses.main = "172.16.0.11";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node3 = {
      addresses.main = "172.16.0.12";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node4 = {
      addresses.main = "172.16.0.13";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node5 = {
      addresses.main = "172.16.0.14";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node6 = {
      addresses.main = "172.16.0.15";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node7 = {
      addresses.main = "172.16.0.17";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node8 = {
      addresses.main = "172.16.0.18";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node9 = {
      addresses.main = "172.16.0.19";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node10 = {
      addresses.main = "172.16.0.20";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node11 = {
      addresses.main = "172.16.0.21";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node12 = {
      addresses.main = "172.16.0.22";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node13 = {
      addresses.main = "172.16.0.23";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node14 = {
      addresses.main = "172.16.0.24";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node15 = {
      addresses.main = "172.16.0.25";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node17 = {
      addresses.main = "172.16.0.27";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    node18 = {
      addresses.main = "172.16.0.28";
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    nasbox = {
      addresses.main = "172.16.0.6";
      vzNode.role = "storage";
      services.node-exporter = {};
    };
  };
}
