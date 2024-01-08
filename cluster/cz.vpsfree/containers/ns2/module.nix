{ config, pkgs, ... }:
{
  cluster."cz.vpsfree/containers/ns2" = {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 25114;
    host = { name = "ns2"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "37.205.11.51"; prefix = 32; } ];
      v6 = [ { address = "2a03:3b40:101:ca::1"; prefix = 64; } ];
    };
    services = {
      bind = {};
      bind-exporter = {};
      node-exporter = {};
    };
    tags = [ "dns" "public-dns" "auto-update" ];
    healthChecks = import ../../../../health-checks/public-dns.nix {
      inherit pkgs;
      ns = "ns2.vpsfree.cz";
    };
  };
}
