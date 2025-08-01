{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../common/all.nix
    ../common/api.nix
  ];

  system.stateVersion = "22.05";
}
