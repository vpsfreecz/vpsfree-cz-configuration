{ config, ... }:
{
  cluster."vpsfree.cz".prg."alerts.int" = rec {
    type = "container";
    spin = "nixos";
    addresses.primary = { address = "172.16.4.11"; prefix = 32; };
    services = {
      alertmanager = {};
      node-exporter = {};
    };
  };
}
