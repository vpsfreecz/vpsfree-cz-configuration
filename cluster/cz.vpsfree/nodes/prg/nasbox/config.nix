{ config, lib, pkgs, ... }:
{
  imports = [
    ../../common/storage.nix
    ../../common/netboot.nix
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin = {
      net_interfaces = [ "teng0" "teng1" ];
    };
    console = {
      enable = false;
      host = "172.16.0.6";
    };
  };

  boot.kernelModules = [ "8021q" ];

  boot.zfs.moduleParams.zfs = {
    "zfs_arc_min" = 48 * 1024*1024*1024;
    "zfs_arc_max" = 128 * 1024*1024*1024;
  };

  boot.zfs.pools.storage = {
    guid = "2575935829831167981";

    install = true;

    scrub = {
      enable = true;
      startIntervals = [ "0 23 1 */2 *" ];
      pauseIntervals = [ "0 7 * * *" ];
      resumeIntervals = [ "1 23 * * *" ];
    };
  };
}
