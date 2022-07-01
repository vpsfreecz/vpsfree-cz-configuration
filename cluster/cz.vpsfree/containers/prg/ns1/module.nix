{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/ns1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = TODO;
    host = { name = "ns1"; location = "prg"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "37.205.9.100"; prefix = 32; } ];
      v6 = [ { address = "2a01:430:17:1::ffff:666"; prefix = 128; } ];
    };
    services = {
      unbound = {};
      node-exporter = {};
      prometheus = {};
    };
    tags = [ "dns" "dns-resolver" ];
  };
}
