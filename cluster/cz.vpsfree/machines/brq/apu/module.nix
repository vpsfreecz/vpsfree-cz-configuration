{ config, ... }:
{
  cluster."cz.vpsfree/machines/brq/apu" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" ];
    host = { name = "apu"; location = "int.brq"; domain = "vpsfree.cz"; target = "172.19.254.254"; };
    addresses.primary = { address = "172.19.254.254"; prefix = 24; };
    tags = [ "apu" ];
    services = {
      node-exporter = {};
      sachet = {};
    };
  };
}
