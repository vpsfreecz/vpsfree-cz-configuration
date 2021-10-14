{ pkgs, lib, config, ... }:
{
  imports = [
    ../common/all.nix
    ../common/redis.nix
  ];
}
