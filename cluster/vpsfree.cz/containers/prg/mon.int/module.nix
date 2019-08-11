{ config, ... }:
{
  cluster."vpsfree.cz".prg."mon.int" = rec {
    type = "container";
    spin = "nixos";
    addresses.primary = "172.16.4.10";
    services = {
      node-exporter = {};
      prometheus = {};
    };
  };
}
