{ config, pkgs, lib, ...}:
{
  imports = [
    ../common.nix
    ../../common/netboot.nix
    ../../common/tank.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" ];
      layout = [
        { type = "raidz"; devices = [ "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" ]; }
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
    { device = "/dev/nvme4n1p2"; }
  ];
}
