{
  config,
  pkgs,
  lib,
  confLib,
  ...
}:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ../../../../configs/webs
  ];

  system.stateVersion = "22.05";
}
