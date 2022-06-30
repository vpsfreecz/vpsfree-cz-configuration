{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.ns2" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 21851;
    host = { name = "ns2"; location = "int.prg"; domain = "vpsfree.cz"; target = "172.16.9.190"; };
    addresses.primary = { address = "172.16.9.190"; prefix = 32; };
    services = {
      bind = {};
      node-exporter = {};
      prometheus = {};
    };
    tags = [ "dns" "internal-dns" ];
  };
}
