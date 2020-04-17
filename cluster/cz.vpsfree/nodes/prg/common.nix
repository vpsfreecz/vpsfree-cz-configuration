{ config, lib, pkgs, data, ... }:
{
  imports = [
    ../common/all.nix
    ../common/netboot.nix
    ../common/tank.nix
  ];

  boot.kernelParams = [
    "intel_idle.max_cstate=1"
  ];
}
