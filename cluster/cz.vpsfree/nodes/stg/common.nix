{ config, lib, pkgs, ... }:
{
  imports = [
    ../common/all.nix
  ];

  boot.kernelParams = [
    "intel_idle.max_cstate=1"
  ];
}
