{ config, lib, pkgs, ... }:
{
  imports = [
    ./all.nix
  ];

  programs.bash.root.historyPools = [ "storage" ];

  boot.zfs.pools.storage = {
    datasets = {
      "/".properties = {
        dnodesize = "legacy";
        recordsize = "128k";
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

  vpsadmin.nodectld.settings = {
    storage = {
      status_interval = 900;
      update_interval = 600;
    };
  };
}
