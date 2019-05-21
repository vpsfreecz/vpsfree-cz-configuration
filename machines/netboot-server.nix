{ lib, config, pkgs, ... }:

with lib;

let
  pinned = import ../pinned.nix { inherit lib pkgs; };

  nixosBuild = {modules ? []}:
    (import (pinned.nixpkgsVpsFree.path + "/nixos/lib/eval-config.nix") {
      system = "x86_64-linux";
      modules = [
        (pinned.nixpkgsVpsFree.path + "/nixos/modules/installer/netboot/netboot-minimal.nix")
      ] ++ modules;
    }).config.system.build;

  nixosNetboot = {modules ? []}:
    let
      build = nixosBuild { inherit modules; };
    in {
      toplevel = build.toplevel;
      dir = pkgs.symlinkJoin {
        name = "nixos_netboot";
        paths = with build; [ netbootRamdisk kernel netbootIpxeScript ];
      };
    };

  node = {modules ? []}:
    let
      common = {
          imports = [
            "${pinned.vpsadminosSrc}/os/configs/common.nix"
          ]; };
      build = pinned.vpsadminosBuild { modules = modules ++ [common]; };
    in {
      toplevel = build.toplevel;
      kernelParams = build.kernelParams;
      dir = pkgs.symlinkJoin {
        name = "vpsadminos_netboot";
        paths = with build; [ dist ];
      };
    };

  vpsadminosISO =
    let
      build = pinned.vpsadminosBuild {
        modules = [{
          imports = [
            "${pinned.vpsadminosSrc}/os/configs/iso.nix"
          ];

          system.secretsDir = null;
        }];
      };
    in build.isoImage;

  inMenu = name: netbootitem: netbootitem // { menu = name; };

  # stock NixOS
  nixos = nixosNetboot { };
  nixosZfs = nixosNetboot {
    modules = [ {
        boot.supportedFilesystems = [ "zfs" ];
      } ];
  };

  nixosZfsSSH = nixosNetboot {
    modules = [ {
        imports = [ ../env.nix ];
        boot.supportedFilesystems = [ "zfs" ];
        # enable ssh
        systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
      } ];
  };

  # stock vpsAdminOS
  vpsadminos = node { };

  # storage nodes
  backuper = node {
    modules = [ {

      imports = [
        ../nodes/backuper.nix
      ];

    } ];
  };

  # node configurations
  node1_stg = node {
    modules = [ {

      imports = [
        ../nodes/node1.stg.nix
      ];

    } ];
  };

  node2_stg = node {
    modules = [ {

      imports = [
        ../nodes/node2.stg.nix
      ];

    } ];
  };

  macMap = {
    backuper = [
      "00:25:90:2f:a3:ac"
      "00:25:90:2f:a3:ad"
      "00:25:90:2f:a3:ae"
      "00:25:90:2f:a3:af"
    ];

    node1_stg = [
      "0c:c4:7a:30:76:18"
      "0c:c4:7a:30:76:19"
      "0c:c4:7a:30:76:1a"
      "0c:c4:7a:30:76:1b"
    ];

    node2_stg = [
      "0c:c4:7a:ab:b4:43"
      "0c:c4:7a:ab:b4:42"
    ];
  };

  # netboot.mappings is in form { "MAC1" = "nodeX"; "MAC2" = "nodeX"; }
  macToItems = lib.listToAttrs (lib.flatten (lib.mapAttrsToList (x: y: map (mac: lib.nameValuePair mac x) y) macMap));

in {
  imports = [
    ../modules/network-wide.nix
    ../modules/netboot.nix
    ../modules/web.nix
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 68 69 ];

  netboot.host = lib.mkDefault "netboot";
  netboot.password = lib.mkDefault "letmein";
  netboot.nixos_items = {
    nixos = inMenu "NixOS" nixos;
    nixoszfs = inMenu "NixOS ZFS" nixosZfs;
    nixoszfsssh = inMenu "NixOS ZFS SSH" nixosZfsSSH;
  };
  netboot.vpsadminos_items = {
    #vpsadminos = inMenu "vpsAdminOS" vpsadminos;
    inherit backuper;
    inherit node1_stg;
    inherit node2_stg;
  };

  netboot.includeNetbootxyz = true;
  netboot.mapping = macToItems;

  web.isoImages = [ vpsadminosISO ];
}
