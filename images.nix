{ pkgs, lib, ... }:
with lib;
let
  swpins = import ./swpins { name = "images"; inherit pkgs lib; };

  # allows to build vpsadminos with specific
  vpsadminosCustom = {modules ? [], vpsadminos, nixpkgs, vpsadmin}:
    let
      # this is fed into scopedImport so vpsadminos sees correct <nixpkgs> everywhere
      overrides = {
        __nixPath = [ { prefix = "nixpkgs"; path = nixpkgs; } ] ++ builtins.nixPath;
        import = fn: scopedImport overrides fn;
        scopedImport = attrs: fn: scopedImport (overrides // attrs) fn;
        builtins = builtins // overrides;
      };
    in
      builtins.scopedImport overrides (vpsadminos + "/os/") {
        pkgs = nixpkgs;
        system = "x86_64-linux";
        configuration = {};
        inherit modules vpsadmin;
      };

  vpsadminos = {modules ? [], ...}@args: vpsadminosCustom {
    inherit modules;
    vpsadminos = args.vpsadminos or swpins.vpsadminos;
    nixpkgs = args.nixpkgs or swpins.nixpkgs;
    vpsadmin = args.vpsadmin or swpins.vpsadmin;
  };

  vpsadminosBuild = args: (vpsadminos args).config.system.build;

in rec {
  nixosBuild = {modules ? []}:
    (import ("${swpins.nixpkgs}/nixos/lib/eval-config.nix") {
      system = "x86_64-linux";
      modules = [
        ("${swpins.nixpkgs}/nixos/modules/installer/netboot/netboot-minimal.nix")
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

  node = {fqdn, modules ? []}:
    let
      nodepins = import ./swpins { name = fqdn; inherit pkgs lib; };
      build = vpsadminosBuild {
        inherit modules;
        inherit (nodepins) vpsadminos nixpkgs vpsadmin;
      };
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
      build = vpsadminosBuild {
        modules = [{
          imports = [
            "${swpins.vpsadminos}/os/configs/iso.nix"
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
        imports = [ ./env.nix ];
        boot.supportedFilesystems = [ "zfs" ];
        # enable ssh
        systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
      } ];
  };

  # stock vpsAdminOS
  vpsadminos = node { };

  # storage nodes
  backuper_prg = node {
    fqdn = "backuper.prg.vpsfree.cz";
    modules = [ {

      imports = [
        ./nodes/vpsfree.cz/prg/backuper.nix
      ];

    } ];
  };

  # node configurations
  node1_stg = node {
    fqdn = "node1.stg.vpsfree.cz";
    modules = [ {

      imports = [
        ./nodes/vpsfree.cz/stg/node1.nix
      ];

    } ];
  };

  node2_stg = node {
    fqdn = "node2.stg.vpsfree.cz";
    modules = [ {

      imports = [
        ./nodes/vpsfree.cz/stg/node2.nix
      ];

    } ];
  };

  macMap = {
    backuper_prg = [
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
  mappings = lib.listToAttrs (lib.flatten (lib.mapAttrsToList (x: y: map (mac: lib.nameValuePair mac x) y) macMap));

  nixosItems = {
    nixos = inMenu "NixOS" nixos;
    nixoszfs = inMenu "NixOS ZFS" nixosZfs;
    nixoszfsssh = inMenu "NixOS ZFS SSH" nixosZfsSSH;
  };

  vpsadminosItems = {
    inherit backuper_prg;
    inherit node1_stg;
    inherit node2_stg;
  };
}
