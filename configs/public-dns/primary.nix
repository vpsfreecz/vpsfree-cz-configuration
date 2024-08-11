{ config, lib, ... }:
{
  services.bind = {
    zones = import ./zones.nix { inherit lib; primary = true; };
  };
}
