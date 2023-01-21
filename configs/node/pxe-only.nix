# This config is imported ONLY when building node image for PXE
{ config, pkgs, confMachine, ... }:
let
  kernels = import ./kernels.nix { inherit pkgs; };
in {
  boot.kernelVersion = kernels.getBootKernelForMachine confMachine.name;
}
