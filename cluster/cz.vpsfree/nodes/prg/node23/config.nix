{ config, pkgs, lib, ... }:
{
  imports = [
    ../common.nix
    ../../common/amd.nix
    ../../common/amd-dual-socket.nix
    ../../common/tunables-2t.nix
  ];

  boot.initrd.kernelModules = [ "i40e" ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" ];
      layout = [
        { type = "raidz"; devices = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" ]; }
      ];
      properties = {
        ashift = "12";
        "feature@block_cloning" = "disabled";
      };
      datasets = {
        "reservation".properties = {
          refreservation = "400G";
        };
      };
    };

    dozer = {
      install = true;
      wipe = [ "sdh" "sdi" "sdj" "sdk" "sdl" "sdm" "sdn" ];
      layout = [
        { type = "raidz"; devices = [ "sdh" "sdi" "sdj" "sdk" "sdl" "sdm" "sdn" ]; }
      ];
      properties = {
        ashift = "12";
        "feature@block_cloning" = "disabled";
      };

      # Configure datasets and scrub as they would be in common/tank.nix
      datasets = {
        "/".properties = {
          compression = "on";
          dnodesize = "legacy";
          recordsize = "128k";
          xattr = "sa";
        };
        "ct".properties = {
          acltype = "posixacl";
        };
        "reservation".properties = {
          refreservation = lib.mkDefault "400G";
          canmount = "off";
        };
      };

      scrub = {
        enable = true;
        startIntervals = [ "0 4 1-7 * *" ];
        startCommand = ''[ "$(LC_ALL=C date '+\%a')" = "Sun" ] && scrubctl start dozer'';
      };
    };
  };

  osctl.pools.tank = {
    parallelStart = 10;
    parallelStop = 20;
  };

  osctl.pools.dozer = {
    parallelStart = 10;
    parallelStop = 20;
  };

  osctld.settings.cpu_scheduler.enable = true;

  boot.enableUnifiedCgroupHierarchy = true;

  swapDevices = [
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin.queues.zfs_send.threads = 6;
  };
}
