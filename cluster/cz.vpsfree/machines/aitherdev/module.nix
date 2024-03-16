{ config, ... }:
{
  cluster."cz.vpsfree/machines/aitherdev" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" ];
    host = { name = "aitherdev"; location = "int"; domain = "vpsfree.cz"; target = "172.16.106.16"; };
    addresses = {
      v4 = [ { address = "172.16.106.16"; prefix = 24; } ];
    };
    tags = [ "auto-update" ];
  };
}
