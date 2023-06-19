{ config, pkgs, lib, confDir, confLib, confData, confMachine, ... }:
let
  images = import ../../../../lib/images.nix {
    inherit config lib pkgs confDir confLib confData confMachine;
    nixosModules = [
      ../../../../environments/base.nix
    ];
  };
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../environments/deploy.nix

    <vpsadminos/os/modules/services/misc/build-vpsadminos-container-image-repository/nixos.nix>
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
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "50%";
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
    settings.max-jobs = 8;
    nrBuildUsers = 128;
  };

  services.build-vpsadminos-container-image-repository.vpsadminos = {
    enable = true;
    osVm = {
      memory = 10240;
      cpus = 16;
      cpu.cores = 16;
      disks = [
        { type = "file"; device = "sda.img"; size = "60G"; }
      ];
    };
    postRunCommands = ''
      ${pkgs.rsync}/bin/rsync -av --delete -e ${pkgs.openssh}/bin/ssh "${config.services.build-vpsadminos-container-image-repository.vpsadminos.repositoryDirectory}/" images.int.vpsadminos.org:/srv/images/
    '';
    systemd.timer.enable = true;
  };

  services.netboot = {
    enable = true;
    host = "172.16.106.5";
    inherit (images) nixosItems;
    vpsadminosItems = images.allNodes "vpsfree.cz";
    copyItems = false;
    includeNetbootxyz = true;
    allowedIPRanges = [
      "172.16.254.0/24"
      "172.19.254.0/24"
    ];
  };

  system.stateVersion = "22.05";
}
