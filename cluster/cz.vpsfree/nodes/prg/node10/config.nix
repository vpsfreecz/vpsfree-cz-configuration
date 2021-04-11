{ config, lib, ... }:
{
  imports = [
    ../common.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" "sdh" ];
      layout = [
        { type = "mirror"; devices = [ "sda" "sdb" ]; }
        { type = "mirror"; devices = [ "sdc" "sdd" ]; }
        { type = "mirror"; devices = [ "sdg" "sdh" ]; }
      ];
      log = [
        { mirror = true; devices = [ "sde1" "sdf1" ]; }
      ];
      cache = [
        "sde3"
        "sdf3"
      ];
      partition = {
        sde = {
          p1 = { sizeGB=10; };
          p2 = { sizeGB=214; };
          p3 = {};
        };
        sdf = {
          p1 = { sizeGB=10; };
          p2 = { sizeGB=214; };
          p3 = {};
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
