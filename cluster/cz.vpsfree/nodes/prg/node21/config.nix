{ config, pkgs, lib, ... }:
{
  imports = [
    ../common.nix
    ../../common/tunables-1t.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" "sdh" ];
      layout = [
        { type = "raidz"; devices = [ "sdc" "sdd" "sde" "sdf" "sdg" "sdh" ]; }
      ];
      log = [
        { mirror = true; devices = [ "sda1" "sdb1" ]; }
      ];
      cache = [
        "sda3"
        "sdb3"
      ];
      partition = {
        sda = {
          p1 = { sizeGB=10; };
          p2 = { sizeGB=214; };
          p3 = {};
        };
        sdb = {
          p1 = { sizeGB=10; };
          p2 = { sizeGB=214; };
          p3 = {};
        };
      };
      properties = {
        ashift = "12";
      };
      datasets = {
        "reservation".properties = {
          refreservation = "300G";
        };
      };
    };
  };

  osctl.pools.tank = {
    parallelStart = 10;
    parallelStop = 30;
  };

  osctld.settings.cpu_scheduler.enable = true;

  boot.enableUnifiedCgroupHierarchy = true;

  swapDevices = [
    # { label = "swap1"; }
    # { label = "swap2"; }
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin.queues.zfs_send.threads = 5;
  };

  # Workaround for a bug in kernel which causes node_exporter to get stuck
  # while reading power info from /sys.
  #
  # /proc/pid/stack reads as:
  # [<0>] show_power+0x34/0x100 [acpi_power_meter]
  # [<0>] dev_attr_show+0x19/0x40
  # [<0>] sysfs_kf_seq_show+0xbe/0x160
  # [<0>] seq_read_iter+0x11c/0x4b0
  # [<0>] new_sync_read+0x115/0x1a0
  # [<0>] vfs_read+0x14b/0x1a0
  # [<0>] ksys_read+0x5f/0xe0
  # [<0>] do_syscall_64+0x33/0x40
  # [<0>] entry_SYSCALL_64_after_hwframe+0x44/0xa9
  #
  # Related to these paths:
  #   /sys/class/hwmon/hwmon9
  #   /sys/bus/acpi/drivers/power_meter
  #   /sys/devices/LNXSYSTM:00/LNXSYBUS:00/ACPI000D:00
  #
  services.prometheus.exporters.node.disabledCollectors = [ "hwmon" ];
}
