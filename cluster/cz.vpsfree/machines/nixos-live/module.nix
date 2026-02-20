{ config, ... }:
{
  cluster."cz.vpsfree/machines/nixos-live" = rec {
    spin = "nixos";
    pins.channels = [ "nixos-stable" ];
    host = {
      name = "nixos-live";
      fqdn = "nixos-live";
      target = null;
    };
    netboot.enable = true;
  };
}
