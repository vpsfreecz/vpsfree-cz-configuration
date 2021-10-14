{ pkgs, lib, config, ... }:
{
  imports = [
    ../common/all.nix
    ../common/database.nix
  ];
}
