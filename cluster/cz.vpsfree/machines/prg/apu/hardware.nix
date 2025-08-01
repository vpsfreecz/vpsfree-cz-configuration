{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "ehci_pci"
    "usb_storage"
    "sd_mod"
    "sr_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/c29d9af9-1d8e-4ab8-baaf-383615fcffc5";
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/2a28599f-0fc9-47c6-a055-02e2af6e9ff3"; }
  ];

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
