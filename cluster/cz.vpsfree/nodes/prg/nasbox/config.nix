{ config, lib, pkgs, ...}:
{
  imports = [
    ../../common/storage.nix
    ../../common/netboot.nix
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin = {
      net_interfaces = [ "oneg0" "oneg1" ];
    };
    console = {
      host = "172.16.0.6";
    };
  };

  boot.kernelModules = [ "8021q" ];

  services.nfs.server.nfsd.nproc = 16;

  boot.zfs.moduleParams.zfs = {
    "zfs_arc_min" = 48 * 1024*1024*1024;
    "zfs_arc_max" = 128 * 1024*1024*1024;
  };

  boot.zfs.pools.storage = {
    guid = "2575935829831167981";

    scrub = {
      enable = true;
      startIntervals = [ "0 23 1 */2 *" ];
      pauseIntervals = [ "0 7 * * *" ];
      resumeIntervals = [ "1 23 * * *" ];
    };
  };
}
