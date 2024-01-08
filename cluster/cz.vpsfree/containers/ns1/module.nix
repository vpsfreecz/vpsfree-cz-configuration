{ config, pkgs, ... }:
{
  cluster."cz.vpsfree/containers/ns1" = {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 25113;
    host = { name = "ns1"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "77.93.223.251"; prefix = 32; } ];
      v6 = [ { address = "2a03:3b40:fe:3fd::1"; prefix = 64; } ];
    };
    services = {
      bind = {};
      bind-exporter = {};
      node-exporter = {};
    };
    tags = [ "dns" "public-dns" "auto-update" ];
    healthChecks = import ../../../../health-checks/public-dns.nix {
      inherit pkgs;
      ns = "ns1.vpsfree.cz";
    };
  };
}
