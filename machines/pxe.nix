{ config, pkgs, lib, ... }:
let
  images = import ../images.nix { inherit lib pkgs; };
in
{
  imports = [
    ../modules/netboot.nix
    ../modules/monitored.nix
  ];

  netboot = {
    host = "172.16.254.5";
    inherit (images) nixosItems vpsadminosItems mappings;
    includeNetbootxyz = true;
    allowedIPRanges = [
      "172.16.254.0/24"
      "172.19.254.0/24"
    ];
  };
}
