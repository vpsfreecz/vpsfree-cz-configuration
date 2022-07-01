{ config, ... }:
{
  cluster."cz.vpsfree/containers/brq/ns2" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = TODO;
    host = { name = "ns2"; location = "brq"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "37.205.11.222"; prefix = 32; } ];
      v6 = [ { address = "2a03:3b40:100::1:222"; prefix = 128; } ];
    };
    services = {
      unbound = {};
      node-exporter = {};
      prometheus = {};
    };
    tags = [ "dns" "dns-resolver" ];
  };
}
