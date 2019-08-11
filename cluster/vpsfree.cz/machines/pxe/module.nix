{ config, ... }:
{
  cluster."vpsfree.cz".global.pxe = rec {
    type = "machine";
    spin = "nixos";
    addresses.primary = "172.16.254.5";
    services.node-exporter = {};
  };
}
