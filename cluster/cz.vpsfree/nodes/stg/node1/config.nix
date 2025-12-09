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
    ../../common/tunables-256g.nix
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
      };
    };
  };

  boot.kernel.sysctl."vm.swappiness" = 100;

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/0b034394-e557-4678-9176-9ba392d62c8d";
      priority = 0;
    }
    {
      device = "/dev/disk/by-uuid/6c6ad700-984f-46e0-bf0d-524d3025bbc1";
      priority = 0;
    }
  ];

  osctl.pools.tank = {
    parallelStart = 8;
  };

  osctld.settings.cpu_scheduler.enable = true;

  boot.enableUnifiedCgroupHierarchy = true;

  system.vpsadminos.enableUnstable = true;
}
