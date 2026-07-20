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

  services.nginx.enableReload = true;

  system.stateVersion = "22.05";
}
