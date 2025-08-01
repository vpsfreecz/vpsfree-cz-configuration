{ config, ... }:
{
  cluster."cz.vpsfree/machines/nixos-live" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" ];
    host = {
      name = "nixos-live";
      fqdn = "nixos-live";
      target = null;
    };
    netboot.enable = true;
  };
}
