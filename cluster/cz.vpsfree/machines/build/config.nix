{ config, pkgs, lib, ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../environments/deploy.nix
  ];
  boot.loader.grub = {
    enable = true;
    zfsSupport = true;
    efiSupport = true;
    mirroredBoots = [
      {
        devices = [ "nodev" ];
        path = "/boot1";
      }
      {
        devices = [ "nodev" ];
        path = "/boot2";
      }
    ];
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.enableUnstable = true;
  boot.zfs.devNodes = "/dev";

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ "virtio" "virtio_blk" ];

  fileSystems."/" =
    { device = "rpool-build/root/nixos";
      fsType = "zfs";
    };

  fileSystems."/boot1" =
    { device = "/dev/disk/by-uuid/683B-3A71";
      fsType = "vfat";
    };

  fileSystems."/boot2" =
    { device = "/dev/disk/by-uuid/6860-FBD8";
      fsType = "vfat";
    };

  fileSystems."/var/build-tmp" =
    { device = "rpool-build/tmp";
      fsType = "zfs";
    };

  swapDevices = [ ];

  boot.runSize = "50%";
  boot.tmpOnTmpfs = true;
  boot.tmpOnTmpfsSize = "50%";
  services.logind.extraConfig = ''
    RuntimeDirectorySize=50%
  '';

  networking.useDHCP = false;
  networking.interfaces.enp1s0.ipv4.addresses = [{ address = "172.16.106.5"; prefixLength = 24; }];
  networking.defaultGateway = "172.16.106.1";
  networking.hostId = "c0c07e10";

  services.cron.mailto = "admin@lists.vpsfree.cz";

  networking.hostName = "build";

  nix = {
    maxJobs = 8;
    nrBuildUsers = 128;
    binaryCaches = [ "https://cache.vpsadminos.org" ];
    binaryCachePublicKeys = [ "cache.vpsadminos.org:wpIJlNZQIhS+0gFf1U3MC9sLZdLW3sh5qakOWGDoDrE=" ];
  };
}
