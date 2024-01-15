{ config, pkgs, ... }:
let
  addr = "37.205.10.88";
in {
  cluster."cz.vpsfree/containers/prg/ns2" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-unstable" "os-staging" ];
    container.id = 25106;
    host = { name = "ns2"; location = "prg"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = addr; prefix = 32; } ];
      v6 = [ { address = "2a01:430:17:1::ffff:588"; prefix = 128; } ];
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
