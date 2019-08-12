{ config, ... }:
{
  cluster."vpsfree.cz".prg."mon.int" = rec {
    type = "container";
    spin = "nixos";
    addresses.primary = { address = "172.16.4.10"; prefix = 32; };
    services = {
      node-exporter = {};
      prometheus = {};
    };
    monitoring.isMonitor = true;
  };
}
