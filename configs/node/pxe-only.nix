# This config is imported ONLY when building node image for PXE
{ lib, config, pkgs, confMachine, ... }:
let
  kernels = import ./kernels.nix { inherit pkgs lib; };
in {
  boot.kernelVersion = kernels.getBootKernelForMachine confMachine.name;
}
