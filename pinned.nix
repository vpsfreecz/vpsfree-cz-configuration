{ lib, pkgs, ... }:
with builtins;
rec {
  vpsadminos_spec = builtins.fromJSON (builtins.readFile ./pinned/vpsadminos.json);
  vpsadminosGit = trace vpsadminos_spec pkgs.fetchgit {
    inherit (vpsadminos_spec) url rev sha256;
    leaveDotGit = true;
  };

  nixpkgsSorki_spec = builtins.fromJSON (builtins.readFile ./pinned/nixpkgs-sorki.json);

  nixpkgsSorkiGit = pkgs.fetchgit {
    inherit (nixpkgsSorki_spec) url rev sha256;
  };

  nixpkgsSorki = import nixpkgsSorkiGit {};

  vpsadminos = {modules ? []}: (import (vpsadminosGit + "/os/") {
    nixpkgs = nixpkgsSorki.path;
    system = "x86_64-linux";
    extraModules = modules;
  });
  vpsadminosBuild = {modules ? []}: (vpsadminos { inherit modules; }).config.system.build;


  # Docs support

  # fetch a version from runtime-deps branch
  # which contains bundix generated rubygems
  # required for generating documentation
  vpsadminos_docs_deps_spec = builtins.fromJSON (builtins.readFile ./pinned/vpsadminos-docs-deps.json);
  vpsadminosGitDocsDeps = pkgs.fetchgit {
    inherit (vpsadminos_docs_deps_spec) url rev sha256;
  };
  vpsadminosDocsPkgs = import nixpkgsSorkiGit {
    overlays = [
      (import (vpsadminosGitDocsDeps + "/os/overlays/osctl.nix"))
    ];
  };

}
