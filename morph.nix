let
  # Pin the deployment package-set to a specific version of nixpkgs
  newPkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs-channels/archive/180aa21259b666c6b7850aee00c5871c89c0d939.tar.gz";
    sha256 = "0gxd10djy6khbjb012s9fl3lpjzqaknfv2g4dpfjxwwj9cbkj04h";
  }) {};

  legacyPkgs = builtins.fetchTarball {
    url    = "https://d3g5gsiof5omrk.cloudfront.net/nixos/17.09/nixos-17.09.3243.bca2ee28db4/nixexprs.tar.xz";
    sha256 = "1adi0m8x5wckginbrq0rm036wgd9n1j1ap0zi2ph4kll907j76i2";
  };

  pinned = import ./pinned.nix { inherit (newPkgs) lib pkgs; };
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
      ./configs/image-repository.nix
    ];

    deployment = {
      nixPath = [
        { prefix = "nixpkgs"; path = pinned.nixpkgsVpsFreeSrc; }
        { prefix = "vpsadminos"; path = pinned.vpsadminosSrc; }
      ];
      importPath = "${pinned.vpsadminosSrc}/os/default.nix";
    };

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
  };

  # uses network.pkgs
  "pxe.vpsfree.cz" = { config, pkgs, ... }: with pkgs; {
    imports = [
      ./env.nix
      ./machines/pxe.nix
      <nixpkgs/nixos/modules/profiles/minimal.nix>
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

  "vpsadminos.org" = { config, pkgs, ... }: with pkgs; {
    imports = [
      ./env.nix
      ./machines/vpsadminos-org.nix
      "${pinned.buildVpsFreeTemplatesSrc}/files/configuration.nix"
    ];

    deployment = {
      nixPath = [
        { prefix = "nixpkgs"; path = legacyPkgs; }
      ];
      healthChecks = {
        http = [
          {
            scheme = "http";
            port = 80;
            path = "/";
            description = "Check whether nginx is running.";
          }
          {
            scheme = "https";
            port = 443;
            host = "vpsadminos.org";
            path = "/";
            description = "vpsadminos.org is up";
          }
        ];
      };
    };
  };

  "log.vpsfree.cz" = { config, pkgs, ... }: with pkgs; {
    imports = [
      ./env.nix
      ./machines/graylog.nix
      ./profiles/ct.nix
    ];

    deployment = {
      healthChecks = {
        http = [
          {
            scheme = "http";
            port = 80;
            path = "/";
            description = "Check whether nginx is running.";
          }
        ];
      };
    };
  };

  "node1.stg.vpsfree.cz" = { config, pkgs, ... }: with pkgs; {
    imports = [
      ./nodes/node1.stg.nix
    ];

    nixpkgs.overlays = [
      (import "${pinned.vpsadminosSrc}/os/overlays/vpsadmin.nix" pinned.vpsadminSrc)
    ];

    deployment = {
      nixPath = [
        { prefix = "nixpkgs"; path = pinned.nixpkgsVpsFreeSrc; }
        { prefix = "vpsadminos"; path = pinned.vpsadminosSrc; }
      ];
      importPath = "${pinned.vpsadminosSrc}/os/default.nix";
    };
  };

  "node2.stg.vpsfree.cz" = { config, pkgs, ... }: with pkgs; {
    imports = [
      ./nodes/node2.stg.nix
    ];

    nixpkgs.overlays = [
      (import "${pinned.vpsadminosSrc}/os/overlays/vpsadmin.nix" pinned.vpsadminSrc)
    ];

    deployment = {
      nixPath = [
        { prefix = "nixpkgs"; path = pinned.nixpkgsVpsFreeSrc; }
        { prefix = "vpsadminos"; path = pinned.vpsadminosSrc; }
      ];
      importPath = "${pinned.vpsadminosSrc}/os/default.nix";
    };
  };

  "backuper.prg.vpsfree.cz" = { config, pkgs, ... }: with pkgs; {
    imports = [
      ./nodes/backuper.nix
    ];

    nixpkgs.overlays = [
      (import "${pinned.vpsadminosSrc}/os/overlays/vpsadmin.nix" pinned.vpsadminSrc)
    ];

    deployment = {
      nixPath = [
        { prefix = "nixpkgs"; path = pinned.nixpkgsVpsFreeSrc; }
        { prefix = "vpsadminos"; path = pinned.vpsadminosSrc; }
      ];
      importPath = "${pinned.vpsadminosSrc}/os/default.nix";
    };
  };



}
