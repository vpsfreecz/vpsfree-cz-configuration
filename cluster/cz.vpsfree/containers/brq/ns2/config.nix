{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
    ../../../../../configs/dns-resolver.nix
  ];

  system.stateVersion = "23.11";
}
