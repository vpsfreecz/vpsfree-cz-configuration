{ config, lib, pkgs, ...}:
{
  osctl.pools.tank = {
    parallelStart = 4;
    parallelStop = 20;
  };

  boot.zfs.pools = {
    tank = {
      datasets = {
        "/".properties = {
          compression = "on";
          dnodesize = "legacy";
          recordsize = "128k";
          xattr = "sa";
        };
        "ct".properties = {
          acltype = "posixacl";
        };
        "reservation".properties = {
          refreservation = "100G";
          canmount = "off";
        };
      };

      scrub = {
        enable = true;
        interval = "0 4 1-7 * *";
        command = ''[ "$(LC_ALL=C date '+\%a')" = "Sat" ] && zpool scrub tank'';
      };
    };
  };

  programs.bash.root.historyPools = [ "tank" ];
}
