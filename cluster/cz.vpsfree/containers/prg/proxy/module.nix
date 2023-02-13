{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/proxy" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "vpsadmin" ];
    container.id = 14096;
    host = { name = "proxy"; location = "prg"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.140"; prefix = 32; } ];
    };
    services.node-exporter = {};
    tags = [ "vpsadmin" "vpsadmin-noupdate" ];
  };
}
