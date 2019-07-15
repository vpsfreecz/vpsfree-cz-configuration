{ config, lib, pkgs, ...}:
let
  bondIfaces = [ "eth0" "eth1" "eth2" "eth3" ];
  bondVlan = 200;
  bondIP = "172.16.0.5/23";
  bondGateway = "172.16.0.2";
in
{
  imports = [
    ../storage.nix
  ];

  vpsadmin.netInterfaces = [ "eth0" "eth1" ];
  vpsadmin.consoleHost = "172.16.0.5";

  node = {
    nodeId = 160;
    net = {
      hostName = "backuper.prg";
      as = 4200001046;
      mac = {
        teng0 = "00:25:90:0e:5b:1a";
        teng1 = "00:25:90:0e:5b:1b";
      };
      interfaces = {
        teng0 = { v4 = "172.16.251.182/30";   v6 = "2a03:3b40:42:2:46::2/80"; };
        teng1 = { v4 = "172.16.250.182/30";   v6 = "2a03:3b40:42:3:46::2/80"; };
      };
      routerId = "172.16.251.182";
      bgp1neighbor = { v4 = "172.16.251.181"; v6 = "2a03:3b40:42:2:46::1"; };
      bgp2neighbor = { v4 = "172.16.250.181"; v6 = "2a03:3b40:42:3:46::1"; };

      virtIP = null;
    };
  };

  boot.kernelModules = [ "bonding" "8021q" ];
  boot.extraModprobeConfig = "options bonding mode=balance-xor miimon=100 xmit_hash_policy=layer3+4 max_bonds=0";

  networking.custom = ''
    ip link add bond0 type bond
    ${lib.flip lib.concatMapStrings bondIfaces (ifc:
      ''
        ip link set ${ifc} up
        ip link add link ${ifc} name ${ifc}.${toString bondVlan} master bond0 type vlan id ${toString bondVlan}
      ''
    )}
    ip link set bond0 up

    ip addr add ${bondIP} dev bond0
    ip route add default via ${bondGateway} dev bond0

  '';

  # The storage pool on backuper is in some weird state, where it can be seen
  # as two pools with the same name, one faulted with missing devices and one
  # as it should be. This issue manifests whenever zpool import -d is used, so
  # we want to import the pool without it.
  boot.zfs.devNodes = [];

  boot.zfs.pools = {
    storage = {
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
