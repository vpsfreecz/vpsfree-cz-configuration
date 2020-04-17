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
        };
        "ct".properties = {
          acltype = "posixacl";
        };
        "reservation".properties = {
          refreservation = "100G";
          canmount = "off";
        };
      };
    };
  };

  programs.bash.root.historyPools = [ "tank" ];
}
