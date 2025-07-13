{ config, lib, ... }:
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
    "spl_panic_halt" = 1;
    "spl_taskq_thread_timeout_ms" = 60000;
  };

  boot.zfs.moduleParams.zfs = {
    "zfs_dmu_offset_next_sync" = 0;
    "zfs_abd_scatter_max_order" = 2;
  };
}
