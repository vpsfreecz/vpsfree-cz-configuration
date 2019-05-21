{ config, pkgs, lib, ... }:
{
  imports = [
    ../modules/deploy.nix
  ];

  boot.extraModprobeConfig = "options zfs zfs_arc_max=${toString (2 * 1024 * 1024 * 1024)}";
}
