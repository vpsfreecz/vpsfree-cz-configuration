{ config, pkgs, lib, ...}:
{
  imports = [
    ../common.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sdc" "sdd" "sde" ];
      layout = [
        { type = "raidz"; devices = [ "sdc" "sdd" "sde" ]; }
      ];
      properties = {
        ashift = "12";
      };
    };
  };

  osctl.pools.tank = {
    parallelStart = 8;
  };

  swapDevices = [
    # { label = "swap1"; }
    # { label = "swap2"; }
  ];
}
