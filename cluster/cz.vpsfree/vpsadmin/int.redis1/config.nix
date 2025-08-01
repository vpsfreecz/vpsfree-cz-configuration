{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../common/all.nix
    ../common/redis.nix
  ];

  system.stateVersion = "22.05";
}
