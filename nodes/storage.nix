{ config, lib, pkgs, ...}:
{
  imports = [
    ./common.nix
    ./modules/bird.nix
  ];

  programs.bash.root.historyPools = [ "storage" ];
}
