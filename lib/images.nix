{ config
, pkgs
, lib
, confDir
, confLib
, confData
, nixosModules ? [] }:
with lib;
let
  machines = confLib.getClusterMachines config.cluster;

  machineAttrs = listToAttrs (map (d: nameValuePair d.config.host.fqdn d) machines);

  netbootable = filterAttrs (k: v: v.config.netboot.enable) machineAttrs;

  filterMachines = filter: filterAttrs (k: v: filter v) netbootable;

  filterNodes = filter: filterMachines (v: !isNull v.config.node && (filter v));

  selectNodes = filter: mapAttrs (k: v: nodeImage v) (filterNodes filter);

  # allows to build vpsadminos with specific
  vpsadminosCustom = {modules ? [], vpsadminos, nixpkgs, vpsadmin}:
    let
      # this is fed into scopedImport so vpsadminos sees correct <nixpkgs> everywhere
      overrides = {
        __nixPath = [
          { prefix = "nixpkgs"; path = nixpkgs; }
          { prefix = "vpsadminos"; path = vpsadminos; }
        ] ++ (optional (!isNull vpsadmin) { prefix = "vpsadmin"; path = vpsadmin; })
          ++ builtins.nixPath;
        import = fn: scopedImport overrides fn;
        scopedImport = attrs: fn: scopedImport (overrides // attrs) fn;
        builtins = builtins // overrides;
      };
    in
      builtins.scopedImport overrides (vpsadminos + "/os/") {
        pkgs = nixpkgs;
        system = "x86_64-linux";
        configuration = {};
        modules = modules;
      };

  vpsadminos = {modules ? [], ...}@args: vpsadminosCustom {
    inherit modules;
    vpsadminos = args.vpsadminos or <vpsadminos>;
    nixpkgs = args.nixpkgs or <nixpkgs>;
    vpsadmin = args.vpsadmin or null;
  };

  vpsadminosBuild = args: (vpsadminos args).config.system.build;

  nodeImage = node:
    let
      nodepins = import <confctl/nix/lib/swpins/eval.nix> {
        inherit confDir;
        name = node.name;
        channels = node.config.swpins.channels;
        pkgs = confLib.corePkgs;
        lib = confLib.coreLib;
      };
      osBuild = vpsadminos {
        modules = [
          {
            imports = [
              node.build.toplevel
            ];
          }
        ];
        inherit (nodepins.evaluated) vpsadminos nixpkgs vpsadmin;
      };
    in {
      toplevel = osBuild.config.system.build.toplevel;
      kernelParams = osBuild.config.system.build.kernelParams;
      dir = pkgs.symlinkJoin {
        name =
          let
            hn = osBuild.config.networking.hostName;
            nn = if (hn != "") then hn else "unnamed";
          in "vpsadminos-netboot-${nn}-${osBuild.config.system.osLabel}";
        paths = with osBuild.config.system.build; [ dist ];
      };
      macs = node.config.netboot.macs or [];
    };

  nixosBuild = {modules ? []}:
    (import <nixpkgs/nixos/lib/eval-config.nix> {
      system = "x86_64-linux";
      modules = [
        <nixpkgs/nixos/modules/installer/netboot/netboot-minimal.nix>
        ({ config, pkgs, lib, ... }:
        {
          _module.args = {
            inherit confLib confData;
            confMachine = null;
            swpins = {
              nixpkgs = <nixpkgs>;
            };
            swpinsInfo = {};
          };
        })
      ] ++ (import <confctl/nix/modules/module-list.nix>).nixos
        ++ [ ../modules/cluster ]
        ++ (import ../cluster/module-list.nix)
        ++ modules;
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

  inMenu = name: netbootitem: netbootitem // { menu = name; };

in rec {
  # stock NixOS
  nixos = nixosNetboot { };
  nixosZfs = nixosNetboot {
    modules = [ {
        boot.supportedFilesystems = [ "zfs" ];
      } ];
  };

  nixosZfsSSH = nixosNetboot {
    modules = [ {
        imports = nixosModules;
        boot.supportedFilesystems = [ "zfs" ];
        # enable ssh
        systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
      } ];
  };

  nixosItems = {
    nixos = inMenu "NixOS" nixos;
    nixoszfs = inMenu "NixOS ZFS" nixosZfs;
    nixoszfsssh = inMenu "NixOS ZFS SSH" nixosZfsSSH;
  };

  nodesInLocation = domain: location:
    selectNodes (node: node.config.host.domain == domain && node.config.host.location == location);

  allNodes = domain: selectNodes (node: node.config.host.domain == domain);
}
