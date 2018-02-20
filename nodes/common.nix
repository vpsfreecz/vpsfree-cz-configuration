{ config, lib, pkgs, ...}:
{
  networking.dhcp = true;
  networking.bird.enable = true;

  vpsadminos.nix = true;
  environment.systemPackages = with pkgs; [
    nvi
    screen
    ipmicfg
  ];

  # to be able to include ipmicfg
  nixpkgs.config.allowUnfree = true;
}
