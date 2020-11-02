{ config, ... }:
{
  cluster."cz.vpsfree/machines/pxe" = rec {
    spin = "nixos";
    host = { name = "pxe"; domain = "vpsfree.cz"; };
    addresses.primary = { address = "172.16.254.5"; prefix = 24; };
    services.node-exporter = {};
  };
}
