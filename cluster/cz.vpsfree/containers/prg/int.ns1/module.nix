{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.ns1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 21850;
    host = { name = "ns1"; location = "int.prg"; domain = "vpsfree.cz"; target = "172.16.9.90"; };
    addresses = {
      v4 = [ { address = "172.16.9.90"; prefix = 32; } ];
    };
    services = {
      bind = {};
      node-exporter = {};
      prometheus = {};
    };
    tags = [ "dns" "internal-dns" "manual-update" ];
  };
}
