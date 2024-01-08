{ config, lib, ... }:
{
  imports = [
    ./shared.nix
  ];

  services.bind = {
    zones = import ./zones.nix { inherit lib; master = false; };
  };
}
