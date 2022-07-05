{ config, ... }:
{
  cluster."cz.vpsfree/containers/brq/int.ns1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 21851;
    host = { name = "ns1"; location = "int.brq"; domain = "vpsfree.cz"; target = "172.19.9.90"; };
    addresses.primary = { address = "172.19.9.90"; prefix = 32; };
    services = {
      bind = {};
      node-exporter = {};
      prometheus = {};
    };
    tags = [ "dns" "internal-dns" ];
  };
}
