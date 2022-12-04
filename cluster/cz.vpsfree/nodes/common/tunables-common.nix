{ config, lib, ...}:
{
  boot.kernel.sysctl = {
    "kernel.sched_cfs_bandwidth_slice_us" = 15000;
    "kernel.sched_migration_cost_ns" = 5000000;
    "net.core.busy_poll" = 1;
    "net.core.netdev_budget" = 128;
    "net.core.netdev_budget_usecs" = 1100;
    "user.max_net_namespaces" = lib.mkDefault 256;
    "vm.cgroup_memory_ksoftlimd_loops" = 512;
    "vm.cgroup_memory_ksoftlimd_sleep_msec" = 15000;
    "vm.compaction_proactiveness" = 100;
    "vm.watermark_boost_factor" = 30000;
  };

  boot.zfs.moduleParams.spl = {
    "spl_kmem_cache_reclaim" = 1;
  };

  boot.zfs.moduleParams.zfs = {
    "zfs_arc_dnode_limit_percent" = 30;
    "zfs_arc_meta_limit_percent" = 45;
    "zfs_per_txg_dirty_frees_percent" = 50;
    "zfs_vdev_async_read_max_active" = 16;
    "zfs_vdev_async_write_max_active" = 4;
    "zfs_vdev_max_active" = 32;
    "zfs_vdev_sync_read_max_active" = 16;
  };
}
