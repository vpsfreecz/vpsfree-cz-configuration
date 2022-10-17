{ config, lib, pkgs, ...}:
{
  osctl.pools.tank = {
    parallelStart = lib.mkDefault 4;
    parallelStop = lib.mkDefault 20;
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
          refreservation = lib.mkDefault "100G";
          canmount = "off";
        };
      };

      scrub = {
        enable = true;
        startIntervals = [ "0 4 1-7 * *" ];
        startCommand = ''[ "$(LC_ALL=C date '+\%a')" = "Sat" ] && scrubctl start tank'';
      };
    };
  };

  programs.bash.root.historyPools = [ "tank" ];

  vpsadmin.nodectld.settings = {
    mbuffer = {
      receive = {
        buffer_size = "1G";
        start_writing_at = 80;
      };
    };
  };
}
