{ config, pkgs, lib, ...}:
{
  imports = [
    ../common.nix
    ../../common/tunables-2t.nix
  ];

  boot.kernel.sysctl = {
    "kernel.syslog_ns_print_to_init_ns" = 0;
  };

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" "sdh" "sdi" "sdj" "sdk" "sdl" "sdm" "sdn" ];
      layout = [
        { type = "raidz"; devices = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" ]; }
        { type = "raidz"; devices = [ "sdh" "sdi" "sdj" "sdk" "sdl" "sdm" "sdn" ]; }
      ];
      properties = {
        ashift = "12";
      };
      datasets = {
        "reservation".properties = {
          refreservation = "800G";
        };
      };
    };
  };

  osctl.pools.tank = {
    parallelStart = 20;
    parallelStop = 40;
  };

  osctld.settings.cpu_scheduler = {
    enable = true;
    packages."0".cpu_mask = "8-63,136-191";
  };

  swapDevices = [
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin.queues.zfs_send.threads = 6;
  };
}
