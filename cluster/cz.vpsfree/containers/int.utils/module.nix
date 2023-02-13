{ config, ... }:
{
  cluster."cz.vpsfree/containers/int.utils" = {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 23188;
    host = { name = "utils"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.156"; prefix = 32; } ];
    };
    services = {
      node-exporter = {};
    };
    tags = [ "auto-update" ];
  };
}
