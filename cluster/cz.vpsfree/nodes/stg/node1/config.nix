{ config, pkgs, lib, ... }:
{
  imports = [
    ../common.nix
    ../../common/intel.nix
    ../../common/netboot.nix
    ../../common/tank.nix
    ../../common/tunables-256g.nix
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

  osctld.settings.cpu_scheduler.enable = true;

  boot.enableUnifiedCgroupHierarchy = true;

  system.vpsadminos.enableUnstable = true;
}
