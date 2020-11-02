{ config, lib, ... }:
{
  cluster = {
    "cz.vpsfree/nodes/prg/node2" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node2";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.11"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node3" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node3";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.12"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node4" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node4";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.13"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node5" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node5";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.14"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node6" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node6";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.15"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node8" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node8";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.18"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node9" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node9";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.19"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node10" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node10";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.20"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node11" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node11";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.21"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node12" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node12";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.22"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node14" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node14";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.24"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node17" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node17";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.27"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };

    "cz.vpsfree/nodes/prg/node18" = {
      spin = "openvz";
      node.role = "hypervisor";
      host = {
        name = "node18";
        location = "prg";
        domain = "vpsfree.cz";
      };
      addresses.primary = { address = "172.16.0.28"; prefix = 23; };
      vzNode.role = "hypervisor";
      services.node-exporter = {};
    };
  };
}
