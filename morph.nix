let
  # Pin the deployment package-set to a specific version of nixpkgs
  newPkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs-channels/archive/180aa21259b666c6b7850aee00c5871c89c0d939.tar.gz";
    sha256 = "0gxd10djy6khbjb012s9fl3lpjzqaknfv2g4dpfjxwwj9cbkj04h";
  }) {};

  vpsfPkgs = builtins.fetchTarball {
    url = "https://github.com/vpsfreecz/nixpkgs/archive/bd504d2442e406018592ad64030d73cec7bd36c1.tar.gz";
    sha256 = "02nsp9g1rgalmpv3bmmr38snlr0pznk4b6glm59ssc9m0cwlkdfg";
  };

  /*
  vpsadminos = builtins.fetchTarball {
    url = "https://github.com/vpsfreecz/vpsadminos/archive/a564c638b5606fbde224bd500d1766a5dc6d0dea.tar.gz";
    sha256 = "19drbh0z22f5pfl06b810cysviqrx08hjm8wmn8rds31cvbybbz2";
  };
  */
  vpsadminos = /home/srk/git/vpsadminos;
in
{
  network =  {
    pkgs = newPkgs;
    description = "vpsf hosts";
  };

  "build.vpsfree.cz" = { config, pkgs, ... }: with pkgs; {
    imports = [
      ./env.nix
      ./machines/build.nix
    ];

    deployment = {
      nixPath = [
        { prefix = "nixpkgs"; path = vpsfPkgs; }
        { prefix = "vpsadminos"; path = vpsadminos; }
      ];
      importPath = "${vpsadminos}/os/default.nix";
    };

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

    nix.maxJobs = lib.mkDefault 16;
    powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

    networking.lxcbr = true;
    networking.hostName = "build";

    # 00:25:90:96:8d:90
    networking.static = {
      enable = true;
      ip = "172.16.254.4";
      gw = "172.16.254.1";
      route = "172.16.254.0/24";
    };

    environment.etc."resolv.conf".text = ''
      domain vpsfree.cz
      search vpsfree.cz prg.vpsfree.cz base48.cz
      nameserver 172.18.2.10
      nameserver 172.18.2.11
    '';
  };

  # uses network.pkgs
  "pxe.vpsfree.cz" = { config, pkgs, ... }: with pkgs; {
    imports = [
      ./env.nix
      ./machines/netboot-server.nix
      <nixpkgs/nixos/modules/profiles/minimal.nix>
    ];
    boot.loader.grub.enable = true;
    boot.loader.grub.version = 2;
    boot.loader.grub.device = "/dev/sda";
    boot.loader.grub.copyKernels = true;

    boot.initrd.availableKernelModules = [ "ehci_pci" "ahci" "usbhid" "sd_mod" ];
    boot.kernelModules = [ "kvm-intel" ];
    boot.extraModulePackages = [ ];

    # needs to be default vhost
    netboot.host = "172.16.254.5";
    global.domain = "pxe.vpsfree.cz";

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

    deployment = {
      healthChecks = {
        http = [
          {
            scheme = "http";
            port = 80;
            path = "/";
            description = "Check whether nginx is running.";
            period = 1; # number of seconds between retries
          }
        ];
      };
    };
  };
}
