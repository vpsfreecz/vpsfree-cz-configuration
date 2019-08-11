{ config, ... }:
{
  cluster."vpsfree.cz".global.log = rec {
    type = "container";
    spin = "nixos";
    addresses.primary = "172.16.4.1";
    services.node-exporter = {};
  };
}
