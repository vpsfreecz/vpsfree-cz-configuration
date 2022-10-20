{ config, pkgs, lib, ...}:
{
  imports = [
    ../common.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" "sdh" "sdi" "sdj" "sdk" "sdl" "sdm" "sdn" ];
      layout = [
        { type = "raidz"; devices = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" ]; }
        { type = "raidz"; devices = [ "sdh" "sdi" "sdj" "sdk" "sdl" "sdm" "sdn" ]; }
      ];
      properties = {
        ashift = "12";
      };
      datasets = {
        "reservation".properties = {
          refreservation = "800G";
        };
      };
    };
  };

  osctl.pools.tank = {
    parallelStart = 20;
    parallelStop = 40;
  };

  swapDevices = [
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin.queues.zfs_send.threads = 6;
  };
}
