{ config, ... }:
{
  cluster."cz.vpsfree/machines/aitherdev" = rec {
    spin = "nixos";
    inputs.channels = [ "nixos-stable" "home-manager" ];
    host = {
      name = "aitherdev";
      location = "int";
      domain = "vpsfree.cz";
      target = "172.16.106.40";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.106.40";
          prefix = 24;
        }
      ];
    };
    services.node-exporter = { };
  };
}
