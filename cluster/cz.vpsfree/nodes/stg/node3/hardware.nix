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
    { device = "/dev/disk/by-uuid/f23e9775-1bdb-40ee-ad31-1daeb0f1b15e";
      fsType = "ext4";
    };

  fileSystems."/boot2" =
    { device = "/dev/disk/by-uuid/8aa2d55c-68ce-47c1-9256-7570e0548618";
      fsType = "ext4";
    };

  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 40;
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
}
