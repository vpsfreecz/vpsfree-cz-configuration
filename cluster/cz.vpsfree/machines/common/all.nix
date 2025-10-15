{ config, pkgs, ... }:
{
  imports = [
    ../../../../environments/base.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_6_12;
}
