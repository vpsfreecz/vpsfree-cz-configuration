{ config, lib, ... }:
{
  imports = [
    ../common.nix
    ../../common/intel.nix
    ../../common/tunables-256g.nix
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
          mirror = true;
          devices = [
            "sdi1"
            "sdj1"
          ];
        }
      ];
      partition = {
        sdi = {
          p1 = {
            sizeGB = 20;
          };
          p2 = { };
        };
        sdj = {
          p1 = {
            sizeGB = 20;
          };
          p2 = { };
        };
      };
      properties = {
        ashift = "12";
      };
    };
  };

  boot.enableUnifiedCgroupHierarchy = false;

  swapDevices = [
  ];
}
