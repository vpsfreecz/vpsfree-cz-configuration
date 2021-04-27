{ config, lib, pkgs, ...}:
{
  imports = [
    ./all.nix
  ];

  programs.bash.root.historyPools = [ "storage" ];

  boot.zfs.pools.storage = {
    datasets = {
      "/".properties = {
        dnodesize = "auto";
        recordsize = "1M";
        xattr = "sa";
      };
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
