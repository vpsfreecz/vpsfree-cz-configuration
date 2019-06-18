{ config, pkgs, lib, ... }:
{
  imports = [
    ../modules/deploy.nix
  ];

  networking.lxcbr = true;
  networking.hostName = "build";
  networking.dhcpd = true;
}
