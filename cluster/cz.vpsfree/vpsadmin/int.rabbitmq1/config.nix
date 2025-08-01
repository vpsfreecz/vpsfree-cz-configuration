{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../common/all.nix
    ../common/rabbitmq.nix
  ];

  system.stateVersion = "23.05";
}
