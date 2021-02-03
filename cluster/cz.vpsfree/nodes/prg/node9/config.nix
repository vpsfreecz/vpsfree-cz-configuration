{ config, lib, ... }:
{
  imports = [
    ../common.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" "sdh" "sdi" "sdj" ];
      layout = [
        { type = "mirror"; devices = [ "sda" "sdb" ]; }
        { type = "mirror"; devices = [ "sdc" "sdd" ]; }
        { type = "mirror"; devices = [ "sdg" "sdh" ]; }
        { type = "mirror"; devices = [ "sdi" "sdj" ]; }
      ];
      log = [
        { mirror = true; devices = [ "sde1" "sdf1" ]; }
      ];
      partition = {
        sde = {
          p1 = { sizeGB=10; };
          p2 = {};
        };
        sdf = {
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
    { label = "swap1"; }
    { label = "swap2"; }
  ];
}
