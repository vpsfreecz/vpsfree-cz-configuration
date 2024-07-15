{ pkgs, lib, config, ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ../../../../configs/public-dns/secondary.nix
  ];

  system.stateVersion = "23.11";
}
