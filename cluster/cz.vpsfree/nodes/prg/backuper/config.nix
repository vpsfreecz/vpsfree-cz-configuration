{ config, lib, pkgs, confData, ... }:
{
  imports = [
    ../../common/storage.nix
    ../../common/netboot.nix
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin = {
      net_interfaces = [ "teng0" "teng1" ];
      queues = {
        storage.threads = 8;
        zfs_recv.threads = 48;
      };
    };
    console = {
      host = "172.16.0.5";
    };
  };

  boot.kernelModules = [ "8021q" "nvmet" "nvmet-tcp" "configfs" ];

  runit.services.nvme-target = {
    run = ''
      waitForService networking

      zvol=/dev/zvol/storage/nvme/devstation

      until [ -b "$zvol" ] ; do
        echo "Waiting for $zvol"
        sleep 1
      done

      mount -t configfs none /sys/kernel/config
      mkdir /sys/kernel/config/nvmet/subsystems/devstation
      cd /sys/kernel/config/nvmet/subsystems/devstation
      echo 1 > attr_allow_any_host
      mkdir namespaces/1
      echo $zvol > namespaces/1/device_path
      echo 1 > namespaces/1/enable
      mkdir /sys/kernel/config/nvmet/ports/1
      cd /sys/kernel/config/nvmet/ports/1
      echo 172.16.0.5 > addr_traddr
      echo tcp > addr_trtype
      echo 4420 > addr_trsvcid
      echo ipv4 > addr_adrfam
      ln -s /sys/kernel/config/nvmet/subsystems/devstation subsystems/devstation
    '';
    oneShot = true;
    onChange = "ignore";
  };

  # Allow access to NVME over TCP for devstation
  networking.firewall.extraCommands = lib.concatMapStringsSep "\n" (net: ''
    # Allow access to NVME over TCP from ${net.location} @ ${net.address}/${toString net.prefix}
    iptables -A nixos-fw -p tcp -s ${net.address}/${toString net.prefix} --dport 4420 -j nixos-fw-accept
  '') confData.vpsadmin.networks.management.ipv4;

  # The storage pool on backuper is in some weird state, where it can be seen
  # as two pools with the same name, one faulted with missing devices and one
  # as it should be. This issue manifests whenever zpool import -d is used, so
  # we want to import the pool without it.
  boot.zfs.devNodes = [];

  boot.zfs.pools = {
    storage = {
      guid = "5841452050336007819";

      install = true;

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
}
