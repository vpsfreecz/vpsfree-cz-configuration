{ pkgs }:
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
