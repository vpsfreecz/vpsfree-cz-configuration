{ config, lib, pkgs, ... }:
{
  imports = [
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
  ];

  boot.initrd.availableKernelModules = [
    "ehci_pci"
    "ahci"
    "megaraid_sas"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [
    "bnx2x"
    "megaraid_sas"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  boot.supportedFilesystems = [ "zfs" ];

  hardware.enableRedistributableFirmware = true;

  fileSystems."/" =
    { device = "rpool/root/os";
      fsType = "zfs";
    };

  fileSystems."/boot1" =
    { device = "/dev/disk/by-uuid/6fe86d26-f81e-49e9-af0d-732b67199376";
      fsType = "ext4";
    };

  fileSystems."/boot2" =
    { device = "/dev/disk/by-uuid/bb58217f-4a07-4964-b015-a45ce2560ffa";
      fsType = "ext4";
    };

  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 40;
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
}
