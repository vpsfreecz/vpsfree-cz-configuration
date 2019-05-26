{ config, lib, pkgs, ...}:
{
  imports = [
    ./common.nix
  ];

  programs.bash.root.historyPools = [ "storage" ];
}
