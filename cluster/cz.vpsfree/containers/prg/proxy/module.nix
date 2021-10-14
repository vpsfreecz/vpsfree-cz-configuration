{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/proxy" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-master" "vpsadmin" ];
    container.id = 14096;
    host = { name = "proxy"; location = "prg"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "37.205.14.61"; prefix = 32; } ];
      v6 = [ { address = "2a03:3b40:fe:35::1"; prefix = 64; } ];
    };
    services.node-exporter = {};
  };
}
