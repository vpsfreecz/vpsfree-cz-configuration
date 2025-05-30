{ config, pkgs, ... }:
{
  cluster."cz.vpsfree/containers/mx2" = {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 27627;
    host = { name = "mx2"; domain = "vpsfree.cz"; target = "172.19.9.22"; };
    addresses = {
      v4 = [ { address = "37.205.11.114"; prefix = 32; } ];
      v6 = [ { address = "2a03:3b40:100::1:95"; prefix = 128; } ];
    };
    tags = [ "mx" "auto-update" ];
  };
}
