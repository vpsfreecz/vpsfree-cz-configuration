{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.db" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "vpsadmin" ];
    container.id = 20272;
    host = { name = "db"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.127"; prefix = 32; } ];
    };
    services.node-exporter = {};
    tags = [ "vpsadmin" "db" ];
  };
}
