{ config, pkgs, ... }:
{
  cluster."cz.vpsfree/containers/ns3" = {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "vpsadmin" ];
    container.id = 26017;
    host = { name = "ns3"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "37.205.15.45"; prefix = 32; } ];
      v6 = [ { address = "2a03:3b40:fe:2be::1"; prefix = 64; } ];
    };
    services = {
      bind = {};
      bind-exporter = {};
      node-exporter = {};
    };
    tags = [ "dns" "public-dns" "secondary-dns" "vpsadmin" "auto-update" ];
  };
}
