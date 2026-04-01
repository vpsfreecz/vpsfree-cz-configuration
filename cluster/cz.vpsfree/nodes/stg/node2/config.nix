{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../common.nix
    ../../common/intel.nix
    ../../common/netboot.nix
    ../../common/tank.nix
    ../../common/tunables-768g.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [
        "sdc"
        "sdd"
        "sde"
        "sdf"
        "sdg"
        "sdh"
        "sdi"
        "sdj"
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
            "sdi"
            "sdj"
          ];
        }
      ];
      properties = {
        ashift = "12";
      };
    };
  };

  boot.kernel.sysctl."vm.swappiness" = 100;

  swapDevices = [
    {
      device = "/dev/disk/by-id/wwn-0x55cd2e41500d1c5f";
      priority = 0;
    }
    {
      device = "/dev/disk/by-id/wwn-0x55cd2e41502e2884";
      priority = 0;
    }
  ];

  osctl.pools.tank = {
    parallelStart = 16;
    parallelStop = 32;
  };

  osctld.settings.cpu_scheduler.enable = true;

  boot.enableUnifiedCgroupHierarchy = true;

  system.vpsadminos.enableUnstable = true;
}
