{ config, ... }:
{
  confctl = {
    list.columns = [
      "name"
      "spin"
      "node.role"
      "host.name"
      "host.location"
      "host.domain"
    ];

    runtimeKernels = {
      enable = true;
      stateFile = "configs/node/kernels.json";
      refreshBeforeDeploy = true;
    };

    netbootInventory = {
      enable = true;
      outputFile = "cluster/netbootable.nix";
    };
  };
}
