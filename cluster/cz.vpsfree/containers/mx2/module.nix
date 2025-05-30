{ config, pkgs, ... }:
{
  cluster."cz.vpsfree/containers/mx2" = {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 27627;
    host = {
      name = "mx2";
      domain = "vpsfree.cz";
      target = "172.19.9.22";
    };
    addresses = {
      v4 = [
        {
          address = "172.19.9.22";
          prefix = 32;
        }
      ];
      v6 = [ ];
    };
    monitoring.enable = false;
    logging.enable = false;
    tags = [ "mx" ];
  };
}
