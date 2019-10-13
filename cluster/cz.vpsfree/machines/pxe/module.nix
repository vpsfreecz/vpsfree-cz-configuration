{ config, ... }:
{
  cluster."cz.vpsfree".global.pxe = rec {
    type = "machine";
    spin = "nixos";
    addresses.primary = { address = "172.16.254.5"; prefix = 24; };
    services.node-exporter = {};
  };
}
