{ config, lib, pkgs, ...}:
{
  imports = [
    ./common.nix
  ];

  programs.bash.root.historyPools = [ "storage" ];

  boot.zfs.pools.storage = {
    datasets = {
      "reservation".properties = {
        refreservation = "100G";
      };
    };

    share = "once";
  };

  boot.kernelParams = [
    "intel_idle.max_cstate=1"
  ];
}
