let
  baseSwpins = import ./swpins rec {
    name = "base";
    pkgs = (import <nixpkgs> {});
    lib = pkgs.lib;
  };

  pkgs = import baseSwpins.nixpkgs {};
  lib = pkgs.lib;
  confLib = import ./lib { inherit lib pkgs; };

  baseModules = [
    ./modules/cluster
  ] ++ (import ./cluster/module-list.nix);

  evalConfig = pkgs.lib.evalModules {
    prefix = [];
    check = true;
    modules = baseModules;
    args = {};
  };

  cluster = evalConfig.config.cluster;

  allDeployments = confLib.getClusterDeployments cluster;

  managedDeployments =
    builtins.filter (dep:
      lib.elem dep.spin [ "vpsadminos" "nixos" ]
    ) allDeployments;
in managedDeployments
