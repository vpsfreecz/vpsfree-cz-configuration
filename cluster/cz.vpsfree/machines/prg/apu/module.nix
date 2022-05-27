{ config, ... }:
{
  cluster."cz.vpsfree/machines/prg/apu" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" ];
    host = { name = "apu"; location = "int.prg"; domain = "vpsfree.cz"; target = "172.16.254.254"; };
    addresses.primary = { address = "172.16.254.254"; prefix = 24; };
    tags = [ "apu" ];
    services = {
      node-exporter = {};
      sachet = {};
    };
  };
}
