{ config, lib, ...}:
{
  imports = [ ./tunables-common.nix ];

  boot.zfs.moduleParams.zfs = {
    "zfs_arc_min" = 256 * 1024*1024*1024;
    "zfs_arc_max" = 600 * 1024*1024*1024;
  };
}
