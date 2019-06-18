{ config, pkgs, lib, ... }:
let
  images = import ../images.nix { inherit lib pkgs; };
in
{
  imports = [
    ../modules/netboot.nix
  ];

  netboot = {
    host = "172.16.254.5";
    inherit (images) nixosItems vpsadminosItems mappings;
    includeNetbootxyz = true;
  };
}
