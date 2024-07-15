{ pkgs, lib, config, ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ../../../../configs/public-dns/primary.nix
  ];

  system.stateVersion = "23.11";
}
