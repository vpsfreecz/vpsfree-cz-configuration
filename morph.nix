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
      ./machines/vpsfree.cz/build.nix
    ];

    deployment = {
      nixPath = [
        { prefix = "nixpkgs"; path = pinned.nixpkgsVpsFreeSrc; }
        { prefix = "vpsadminos"; path = pinned.vpsadminosSrc; }
      ];
      importPath = "${pinned.vpsadminosSrc}/os/default.nix";
    };
  };

  # uses network.pkgs
  "pxe.vpsfree.cz" = { config, pkgs, ... }: with pkgs; {
    imports = [
      ./machines/vpsfree.cz/pxe.nix
    ];

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
      ./containers/vpsadminos.org/www.nix
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
      ./containers/vpsfree.cz/log.nix
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

  "mon0.vpsfree.cz" = { config, pkgs, ... }: with pkgs; {
    imports = [
      ./env.nix
      ./containers/vpsfree.cz/mon0.nix
      ./profiles/ct.nix
    ];
  };

  "node1.stg.vpsfree.cz" = { config, pkgs, ... }: with pkgs; {
    imports = [
      ./nodes/vpsfree.cz/stg/node1.nix
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
      ./nodes/vpsfree.cz/stg/node2.nix
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
      ./nodes/vpsfree.cz/prg/backuper.nix
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
