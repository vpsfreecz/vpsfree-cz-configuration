{ config, lib, ... }:
{
  imports = [
    ../common.nix
    ../../common/tank-hdd.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" "sdh" "sdi" "sdj" ];
      layout = [
        { type = "mirror"; devices = [ "sdc" "sdd" ]; }
        { type = "mirror"; devices = [ "sde" "sdf" ]; }
        { type = "mirror"; devices = [ "sdg" "sdh" ]; }
        { type = "mirror"; devices = [ "sdi" "sdj" ]; }
      ];
      log = [
        { mirror = true; devices = [ "sda1" "sdb1" ]; }
      ];
      partition = {
        sda = {
          p1 = { sizeGB=10; };
          p2 = {};
        };
        sdb = {
          p1 = { sizeGB=10; };
          p2 = {};
        };
      };
      properties = {
        ashift = "12";
      };
    };
  };

  swapDevices = [
    # { label = "swap1"; }
    # { label = "swap2"; }
  ];
}
