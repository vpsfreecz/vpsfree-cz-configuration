{ config, pkgs, lib, ...}:
{
  imports = [
    ../common.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "sdc" "sdd" ];
      layout = [
        { type = "raidz"; devices = [ "sda" "sdb" "sdc" "sdd" ]; }
      ];
    };
  };
}
