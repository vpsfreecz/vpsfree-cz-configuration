{ pkgs }:
let
  bootKernels = {
    # machine name => kernel version, for example:
    # "cz.vpsfree/nodes/stg/node1" = "5.10.164";
  };

  runtimeKernels = {
    # machine name => kernel version, for example:
    # "cz.vpsfree/nodes/stg/node1" = "5.10.164";
  };

  # Update with:
  #   confctl runtime-kernels update
  jsonKernels =
    if builtins.pathExists ./kernels.json then
      builtins.fromJSON (builtins.readFile ./kernels.json)
    else
      {};

  vpsadminosKernels = import <vpsadminos/os/packages/linux/availableKernels.nix> { inherit pkgs; };

  defaultKernel = vpsadminosKernels.defaultVersion;
in {
  getBootKernelForMachine = name: bootKernels.${name} or defaultKernel;

  getRuntimeKernelForMachine = name: runtimeKernels.${name} or (jsonKernels.${name} or defaultKernel);
}
