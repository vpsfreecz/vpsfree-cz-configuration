{ config, ... }:
{
  cluster."vpsfree.cz".prg.log = rec {
    type = "container";
    spin = "nixos";
    addresses.primary = { address = "172.16.4.1"; prefix = 32; };
    services.node-exporter = {};
  };
}
