{ config, ... }:
{
  cluster."cz.vpsfree/machines/pxe" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-20.09" ];
    host = { name = "pxe"; domain = "vpsfree.cz"; };
    addresses.primary = { address = "172.16.254.5"; prefix = 24; };
    services.node-exporter = {};
  };
}
