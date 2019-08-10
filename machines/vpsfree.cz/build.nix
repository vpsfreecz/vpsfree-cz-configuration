{ config, pkgs, lib, ... }:
{
  imports = [
    ../../env.nix
    ../../environments/deploy.nix
  ];

  system.monitoring.enable = true;

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.copyKernels = true;

  boot.kernelParams = [ "nolive" ];
  boot.initrd.availableKernelModules = [ "ehci_pci" "ahci" "usbhid" ];
  boot.kernelModules = [ "kvm-intel" "ipmi_si" "ipmi_devintf" ];
  boot.extraModulePackages = [ ];
  boot.extraModprobeConfig = "options zfs zfs_arc_max=${toString (2 * 1024 * 1024 * 1024)}";

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

  nix.maxJobs = lib.mkDefault 16;
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
  networking.hostName = "build";
  networking.dhcpd = true;
}
