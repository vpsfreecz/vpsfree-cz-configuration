{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../common.nix
    ../../common/amd.nix
    ../../common/tunables-1t.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;

      wipe = [
        "nvme0n1"
        "nvme1n1"
        "nvme2n1"
        "nvme3n1"
      ];

      layout = [
        {
          type = "raidz";
          devices = [
            "nvme0n1"
            "nvme1n1"
            "nvme2n1"
            "nvme3n1"
          ];
        }
      ];

      properties = {
        ashift = "12";
        "feature@block_cloning" = "disabled";
      };

      datasets = {
        "reservation".properties = {
          refreservation = "500G";
        };
      };
    };
  };

  osctl.pools.tank = {
    parallelStart = 20;
    parallelStop = 40;
  };

  boot.enableUnifiedCgroupHierarchy = false;

  swapDevices = [
    # none
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin.queues.zfs_send.threads = 5;
  };
}
