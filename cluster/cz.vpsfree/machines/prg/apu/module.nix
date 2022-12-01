{ config, ... }:
{
  cluster."cz.vpsfree/machines/prg/apu" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" ];
    host = { name = "apu"; location = "int.prg"; domain = "vpsfree.cz"; target = "172.16.254.254"; };
    addresses = {
      v4 = [ { address = "172.16.254.254"; prefix = 24; } ];
    };
    tags = [ "apu" "pxe" "pxe-secondary" "vpsf-status" ];
    services = {
      node-exporter = {};
      sachet = {};
    };
  };
}
