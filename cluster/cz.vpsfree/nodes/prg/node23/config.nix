{ config, pkgs, lib, ...}:
{
  imports = [
    ../common.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" "sdh" "sdi" "sdj" "sdk" "sdl" ];
      layout = [
        { type = "raidz"; devices = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" ]; }
        { type = "raidz"; devices = [ "sdg" "sdh" "sdi" "sdj" "sdk" "sdl" ]; }
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
}
