{ config, pkgs, ... }:
{
  cluster."cz.vpsfree/containers/ns4" = {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "vpsadmin" ];
    container.id = 26018;
    host = { name = "ns4"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "37.205.11.85"; prefix = 32; } ];
      v6 = [ { address = "2a03:3b40:101:4::1"; prefix = 64; } ];
    };
    services = {
      bind = {};
      bind-exporter = {};
      node-exporter = {};
    };
    tags = [ "dns" "public-dns" "secondary-dns" "vpsadmin" "auto-update" ];
  };
}
