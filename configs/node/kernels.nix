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

  vpsadminosKernels = import <vpsadminos/os/packages/linux/availableKernels.nix> { inherit pkgs; };

  defaultKernel = vpsadminosKernels.defaultVersion;
in {
  getBootKernelForMachine = name: bootKernels.${name} or defaultKernel;

  getRuntimeKernelForMachine = name: runtimeKernels.${name} or defaultKernel;
}
