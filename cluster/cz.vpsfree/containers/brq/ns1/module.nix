{ config, ... }:
{
  cluster."cz.vpsfree/containers/brq/ns1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 25107;
    host = { name = "ns1"; location = "brq"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "37.205.11.200"; prefix = 32; } ];
      v6 = [ { address = "2a03:3b40:100::1:200"; prefix = 128; } ];
    };
    services = {
      unbound = {};
      unbound-exporter = {};
      node-exporter = {};
    };
    tags = [ "dns" "dns-resolver" "manual-update" ];
  };
}
