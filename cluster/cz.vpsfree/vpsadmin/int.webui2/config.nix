{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../common/all.nix
    ../common/webui.nix
  ];

  system.stateVersion = "22.05";
}
