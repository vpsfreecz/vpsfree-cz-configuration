{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.redis1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "vpsadmin" ];
    container.id = 20277;
    host = { name = "redis1"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.132"; prefix = 32; } ];
    };
    services.node-exporter = {};
    tags = [ "vpsadmin" "redis" ];
  };
}
