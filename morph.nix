let
  baseSwpins = import ./swpins rec {
    name = "base";
    pkgs = (import <nixpkgs> {});
    lib = pkgs.lib;
  };

  deployments = import ./deployments.nix;

  configs = builtins.mapAttrs (k: v: v.config) deployments;
in configs // {
  network =  {
    pkgs = import baseSwpins.nixpkgs {};
    description = "vpsf hosts";
  };
}
