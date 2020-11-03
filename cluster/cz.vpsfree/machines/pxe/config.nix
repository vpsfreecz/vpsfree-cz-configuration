{ config, pkgs, lib, confLib, confData, ... }:
let
  images = import <confctl/nix/lib/images.nix> {
    inherit config lib confLib pkgs confData;
    nixosModules = [
      ../../../../environments/base.nix
    ];
  };
in
{
  imports = [
    ../../../../environments/base.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.copyKernels = true;

  boot.initrd.availableKernelModules = [ "ehci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "tank/root";
      fsType = "zfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/39aebcc2-9cbc-461b-b494-b34c467ca595";
      fsType = "ext4";
    };

  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 8;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  boot.kernelParams = [
    "net.ifnames=0"
  ];

  # 00:25:90:3d:0f:14
  networking = {
    hostName = "pxe";
    hostId = "0fed4e57";
    defaultGateway = "172.16.254.1";
    interfaces = {
      eth0 = {
        ipv4.addresses = [
          { address="172.16.254.5"; prefixLength=24; }
        ];
      };
    };
  };

  services.netboot = {
    enable = true;
    host = "172.16.254.5";
    inherit (images) nixosItems;
    vpsadminosItems = images.allNodes "vpsfree.cz";
    includeNetbootxyz = true;
    allowedIPRanges = [
      "172.16.254.0/24"
      "172.19.254.0/24"
    ];
  };
}
