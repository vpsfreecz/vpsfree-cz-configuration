{ config, pkgs, ... }:
let
  addr = "37.205.9.100";
in {
  cluster."cz.vpsfree/containers/prg/ns1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-unstable" "os-staging" ];
    container.id = 25105;
    host = { name = "ns1"; location = "prg"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = addr; prefix = 32; } ];
      v6 = [ { address = "2a01:430:17:1::ffff:666"; prefix = 128; } ];
    };
    services = {
      kresd-plain = {};
      kresd-management = {};
      node-exporter = {};
    };
    tags = [ "dns" "dns-resolver" "manual-update" ];
    healthChecks = import ../../../../../health-checks/dns-resolver.nix { inherit pkgs addr; };
  };
}
