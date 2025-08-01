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
        "sda"
        "sdb"
        "sdc"
        "sdd"
        "sde"
        "sdf"
        "sdg"
        "sdh"
      ];
      layout = [
        {
          type = "raidz2";
          devices = [
            "sda"
            "sdb"
            "sdc"
            "sdd"
            "sde"
            "sdf"
            "sdg"
            "sdh"
          ];
        }
      ];
      log = [
        {
          mirror = false;
          devices = [ "nvme0n1p1" ];
        }
      ];
      partition = {
        nvme0n1 = {
          p1 = {
            sizeGB = 30;
          };
          p2 = { };
        };
      };
      properties = {
        ashift = "12";
      };
      datasets = {
        "reservation".properties = {
          refreservation = "400G";
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
    # { label = "swap1"; }
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin.queues.zfs_send.threads = 5;
  };
}
