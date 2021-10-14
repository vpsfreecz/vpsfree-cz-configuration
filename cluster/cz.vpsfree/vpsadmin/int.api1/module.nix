{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.api1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-master" "vpsadmin" ];
    container.id = 20273;
    host = { name = "api1"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.128"; prefix = 32; } ];
    };
    services.node-exporter = {};
    tags = [ "vpsadmin" "api" ];
  };
}
