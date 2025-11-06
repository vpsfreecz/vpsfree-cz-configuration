{ config, lib, ... }:
{
  imports = [ ./tunables-common.nix ];

  boot.kernel.sysctl = {
    "vm.min_free_kbytes" = 128 * 1024 * 1024;
  };

  boot.zfs.moduleParams.zfs = {
    "zfs_arc_min" = 256 * 1024 * 1024 * 1024;
    "zfs_arc_max" = 400 * 1024 * 1024 * 1024;
  };

  vpsadmin.nodectld.settings = {
    vpsadmin.queues.zfs_send.start_delay = 35 * 60;
    vpsadmin.queues.zfs_recv.start_delay = 35 * 60;
  };
}
