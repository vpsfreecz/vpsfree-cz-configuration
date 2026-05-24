{
  lib,
  pkgs,
  config,
  inputs,
}:
let
  # Override kernels per-node which are used for boot from PXE
  bootKernels = {
    # machine name => kernel version, for example:
    # "cz.vpsfree/nodes/stg/node1" = "5.10.164";
  };

  # Override kernels per-node used for live updates. For automated runtime kernel
  # detection, see jsonKernels. This setting overrides jsonKernels
  runtimeKernels = {
    # machine name => kernel version, for example:
    # "cz.vpsfree/nodes/stg/node1" = "5.10.164";
  };

  # Auto-generated list of currently running kernels within the cluster
  # Update with:
  #   confctl runtime-kernels update
  #
  # The generated kernels.json is intentionally ignored by git. In flake
  # builds, ./kernels.json points into the filtered flake source, where the
  # ignored file is not present. Since evaluation is already impure, read it
  # from the live checkout first.
  pwd = builtins.getEnv "PWD";
  workingTreeKernelsJson = "${pwd}/configs/node/kernels.json";
  jsonKernels =
    if pwd != "" && builtins.pathExists workingTreeKernelsJson then
      builtins.fromJSON (builtins.readFile workingTreeKernelsJson)
    else if builtins.pathExists ./kernels.json then
      builtins.fromJSON (builtins.readFile ./kernels.json)
    else
      { };

  vpsadminosKernels = import (inputs.vpsadminos + "/os/packages/linux/packages.nix") {
    inherit pkgs lib config;
  };

  defaultKernel = vpsadminosKernels.defaultVersion;
in
{
  getBootKernelForMachine = name: bootKernels.${name} or defaultKernel;

  getRuntimeKernelForMachine = name: runtimeKernels.${name} or (jsonKernels.${name} or defaultKernel);
}
