{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.webui2" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-master" "vpsadmin" ];
    container.id = 20276;
    host = { name = "webui2"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.131"; prefix = 32; } ];
    };
    services.node-exporter = {};
    tags = [ "vpsadmin" "webui" ];
  };
}
