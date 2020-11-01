{ config, lib, pkgs, ... }:
{
  imports = [
    ../common/all.nix
  ];

  boot.kernelParams = [
    "intel_idle.max_cstate=0"
    "processor.max_cstate=0"
    "idle=poll"
  ];
}
