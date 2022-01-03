{ config, ... }:
{
  cluster."cz.vpsfree/machines/build" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" ];
    host = { name = "build"; domain = "vpsfree.cz"; target = "172.16.106.5"; };
    addresses.primary = { address = "172.16.106.5"; prefix = 24; };
    services.node-exporter = {};
  };
}
