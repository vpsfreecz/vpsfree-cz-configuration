{ config, ... }:
{
  cluster."cz.vpsfree/machines/nixos-live" = rec {
    spin = "nixos";
    inputs.channels = [ "nixos-stable" ];
    host = {
      name = "nixos-live";
      fqdn = "nixos-live";
      target = null;
    };
    netboot.enable = true;
  };
}
