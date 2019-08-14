{ config, ... }:
{
  cluster."vpsfree.cz".prg."alerts.int" = rec {
    type = "container";
    spin = "nixos";
    container.id = 14077;
    addresses.primary = { address = "172.16.4.11"; prefix = 32; };
    services = {
      alertmanager = {};
      node-exporter = {};
    };
  };
}
