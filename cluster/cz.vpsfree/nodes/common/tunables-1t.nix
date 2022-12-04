{ config, lib, ...}:
{
  imports = [ ./tunables-common.nix ];

  boot.zfs.moduleParams.zfs = {
    "zfs_arc_min" = 128 * 1024*1024*1024;
    "zfs_arc_max" = 256 * 1024*1024*1024;
  };
}
