{ pkgs, lib, config, ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ../../../../configs/public-dns/slave.nix
  ];

  system.stateVersion = "23.11";
}
