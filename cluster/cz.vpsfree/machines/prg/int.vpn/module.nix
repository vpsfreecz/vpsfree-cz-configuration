{ config, ... }:
{
  cluster."cz.vpsfree/machines/prg/int.vpn" = rec {
    spin = "nixos";
    pins.channels = [ "nixos-stable" ];
    host = {
      name = "vpn";
      location = "int.prg";
      domain = "vpsfree.cz";
      target = "172.16.107.1";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.107.1";
          prefix = 24;
        }
      ];
    };
    services.node-exporter = { };
  };
}
