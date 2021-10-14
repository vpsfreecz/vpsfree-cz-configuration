{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.webui1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-master" "vpsadmin" ];
    container.id = 20275;
    host = { name = "webui1"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.130"; prefix = 32; } ];
    };
    services.node-exporter = {};
    tags = [ "vpsadmin" "webui" ];
  };
}
