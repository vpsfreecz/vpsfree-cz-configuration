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
          type = "raidz";
          devices = [
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
          mirror = true;
          devices = [
            "sda1"
            "sdb1"
          ];
        }
      ];
      cache = [
        "sda3"
        "sdb3"
      ];
      partition = {
        sda = {
          p1 = {
            sizeGB = 10;
          };
          p2 = {
            sizeGB = 214;
          };
          p3 = { };
        };
        sdb = {
          p1 = {
            sizeGB = 10;
          };
          p2 = {
            sizeGB = 214;
          };
          p3 = { };
        };
      };
      properties = {
        ashift = "12";
      };
      datasets = {
        "reservation".properties = {
          refreservation = "300G";
        };
      };
    };
  };

  osctl.pools.tank = {
    parallelStart = 10;
    parallelStop = 30;
  };

  osctld.settings.cpu_scheduler.enable = true;

  boot.enableUnifiedCgroupHierarchy = true;

  swapDevices = [
    # { label = "swap1"; }
    # { label = "swap2"; }
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin.queues.zfs_send.threads = 5;
  };
}
