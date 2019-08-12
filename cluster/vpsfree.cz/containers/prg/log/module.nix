{ config, ... }:
{
  cluster."vpsfree.cz".prg.log = rec {
    type = "container";
    spin = "nixos";
    addresses.primary = "172.16.4.1";
    services.node-exporter = {};
  };
}
