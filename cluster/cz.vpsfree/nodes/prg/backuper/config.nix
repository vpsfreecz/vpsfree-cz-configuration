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
      host = "172.16.0.5";
    };
  };

  boot.kernelModules = [ "8021q" ];

  # The storage pool on backuper is in some weird state, where it can be seen
  # as two pools with the same name, one faulted with missing devices and one
  # as it should be. This issue manifests whenever zpool import -d is used, so
  # we want to import the pool without it.
  boot.zfs.devNodes = [];

  boot.zfs.pools = {
    storage = {
      guid = "5841452050336007819";

      scrub = {
        enable = true;
        startIntervals = [ "0 7 */30 * *" ];
        pauseIntervals = [ "0 1 * * *" ];
        resumeIntervals = [ "0 7 * * *" ];
      };

      layout = [
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x5003048001d802f0-lun-0"
            "pci-0000:03:00.0-sas-0x5003048001d802f2-lun-0"
            "pci-0000:03:00.0-sas-0x5003048000157692-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x5003048001d802ef-lun-0"
            "pci-0000:03:00.0-sas-0x5003048001d802f4-lun-0"
            "pci-0000:03:00.0-sas-0x5003048001d802f3-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x5003048001d802f5-lun-0"
            "pci-0000:03:00.0-sas-0x5003048001d802f7-lun-0"
            "pci-0000:03:00.0-sas-0x5003048001d802f6-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x5003048000157688-lun-0"
            "pci-0000:03:00.0-sas-0x5003048000157689-lun-0"
            "pci-0000:03:00.0-sas-0x500304800015768a-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x500304800015769a-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f318d-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f318e-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x50030480001f318f-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f3190-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f3191-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x50030480001f3195-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f3196-lun-0"
            "pci-0000:03:00.0-sas-0x500304800015768e-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x50030480001f3192-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f3193-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f3194-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x50030480001f3198-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f3199-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f319a-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x50030480001f319b-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f319c-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f319d-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x50030480001f319e-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f319f-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f31a0-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x50030480001f31a1-lun-0"
            "pci-0000:03:00.0-sas-0x500304800015769c-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f31a3-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x500304800015768f-lun-0"
            "pci-0000:03:00.0-sas-0x5003048000157690-lun-0"
            "pci-0000:03:00.0-sas-0x5003048000157696-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x5003048000157693-lun-0"
            "pci-0000:03:00.0-sas-0x5003048000157694-lun-0"
            "pci-0000:03:00.0-sas-0x5003048000157695-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x5003048000157697-lun-0"
            "pci-0000:03:00.0-sas-0x5003048000157698-lun-0"
            "pci-0000:03:00.0-sas-0x5003048000157699-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x500304800015768b-lun-0"
            "pci-0000:03:00.0-sas-0x500304800015768c-lun-0"
            "pci-0000:03:00.0-sas-0x500304800015768d-lun-0"
          ];
        }
        { type = "raidz1";
          devices = [
            "pci-0000:03:00.0-sas-0x5003048000157691-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f318c-lun-0"
            "pci-0000:03:00.0-sas-0x50030480001f31a2-lun-0"
          ];
        }
      ];
      cache = [
        "wwn-0x5e83a97e60d6c045-part2"
        "wwn-0x5e83a97e71bd0af8-part2"
      ];
      spare = [
        "pci-0000:03:00.0-sas-0x5003048001d802ee-lun-0"
        "pci-0000:03:00.0-sas-0x5003048001d802f1-lun-0"
      ];
    };
  };

  nodectld.settings.vpsadmin.queues.zfs_recv.threads = 48;
}
