{ config, pkgs, ... }:
let
  addr = "37.205.11.222";
in {
  cluster."cz.vpsfree/containers/brq/ns2" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 25108;
    host = { name = "ns2"; location = "brq"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = addr; prefix = 32; } ];
      v6 = [ { address = "2a03:3b40:100::1:222"; prefix = 128; } ];
    };
    services = {
      unbound = {};
      unbound-exporter = {};
      node-exporter = {};
    };
    tags = [ "dns" "dns-resolver" "manual-update" ];
    healthChecks = import ../../../../../health-checks/dns-resolver.nix { inherit pkgs addr; };
  };
}
