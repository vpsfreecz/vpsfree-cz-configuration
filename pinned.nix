{ lib, pkgs, ... }:
with builtins;
rec {

  vpsadmin_spec = builtins.fromJSON (builtins.readFile ./pinned/vpsadmin.json);
  vpsadminGit = trace vpsadmin_spec pkgs.fetchgit {
    inherit (vpsadmin_spec) url rev sha256;
    leaveDotGit = true;
  };

  vpsadminos_spec = builtins.fromJSON (builtins.readFile ./pinned/vpsadminos.json);
  vpsadminosGit = trace vpsadminos_spec pkgs.fetchgit {
    inherit (vpsadminos_spec) url rev sha256;
    leaveDotGit = true;
  };
  # if you need to build directly from git for testing
  # - uses filterSource to get rid of .git and a custom filter to exclude possible disk images
  /*
  vpsadminosGit = builtins.trace "[vpsadminos] Building from local git" (builtins.filterSource (p: t:
    lib.cleanSourceFilter p t
    && (!lib.hasSuffix "img" (baseNameOf p))
    && (baseNameOf p != "local.nix")
    ) ../../git/vpsadminos);
  */

  nixpkgsVpsFree_spec = builtins.fromJSON (builtins.readFile ./pinned/nixpkgs-vpsfreecz.json);

  nixpkgsVpsFreeGit = pkgs.fetchgit {
    inherit (nixpkgsVpsFree_spec) url rev sha256;
    leaveDotGit = true;
  };

  nixpkgsVpsFree = import nixpkgsVpsFreeGit {};

  vpsadminos = {modules ? []}:
    let
      # this is fed into scopedImport so vpsadminos sees correct <nixpkgs> everywhere
      overrides = {
        __nixPath = [ { prefix = "nixpkgs"; path = nixpkgsVpsFree.path; } ] ++ builtins.nixPath;
        import = fn: scopedImport overrides fn;
        scopedImport = attrs: fn: scopedImport (overrides // attrs) fn;
        builtins = builtins // overrides;
      };
    in
      builtins.scopedImport overrides (vpsadminosGit + "/os/") {
        nixpkgs = nixpkgsVpsFree.path;
        system = "x86_64-linux";
        configuration = {};
        extraModules = modules;
        vpsadmin = vpsadminGit;
      };
  vpsadminosBuild = {modules ? []}: (vpsadminos { inherit modules; }).config.system.build;

  # Docs support

  # fetch a version from runtime-deps branch
  # which contains bundix generated rubygems
  # required for generating documentation
  vpsadminos_docs_deps_spec = builtins.fromJSON (builtins.readFile ./pinned/vpsadminos-docs-deps.json);
  vpsadminosGitDocsDeps = pkgs.fetchgit {
    inherit (vpsadminos_docs_deps_spec) url rev sha256;
  };
  vpsadminosDocsPkgs = import nixpkgsVpsFreeGit {
    overlays = [
      (import (vpsadminosGitDocsDeps + "/os/overlays/osctl.nix"))
      (import (vpsadminosGit + "/os/overlays/gem-config.nix"))
    ];
  };

}
