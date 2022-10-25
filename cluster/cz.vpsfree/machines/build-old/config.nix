{ config, pkgs, lib, ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../environments/deploy.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.copyKernels = true;

  boot.kernelParams = [ "nolive" ];
  boot.initrd.availableKernelModules = [ "ehci_pci" "ahci" "usbhid" ];
  boot.kernelModules = [ "kvm-intel" "ipmi_si" "ipmi_devintf" ];
  boot.extraModulePackages = [ ];

  boot.zfs.pools = {
    tank = {
      layout = [
        { devices = [ "sda1" ]; }
      ];
    };
  };

  fileSystems."/" =
    { device = "tank/root";
      fsType = "zfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/7b877eb5-8ed4-475b-8739-5a740426e169";
      fsType = "ext4";
    };

  swapDevices = [ ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # 00:25:90:96:8d:90
  networking.static = {
    enable = true;
    ip = "172.16.254.4";
    gw = "172.16.254.1";
    route = "172.16.254.0/24";
  };

  services.cron.mailto = "admin@lists.vpsfree.cz";

  networking.lxcbr = true;
  networking.hostName = "build-old";
  networking.dhcpd = true;

  nix = {
    maxJobs = 5;
  };
}
