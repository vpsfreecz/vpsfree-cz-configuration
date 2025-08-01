{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../common/all.nix
    ../common/database.nix
  ];

  system.stateVersion = "22.05";
}
