{ config, lib, ... }:
{
  imports = [ ./tunables-common.nix ];

  boot.kernel.sysctl = {
    "vm.min_free_kbytes" = 32 * 1024 * 1024;
  };

  boot.zfs.moduleParams.zfs = {
    "zfs_arc_min" = 64 * 1024 * 1024 * 1024;
    "zfs_arc_max" = 128 * 1024 * 1024 * 1024;
  };
}
