let
  pkgs = import <nixpkgs> { overlays = [ (import ./overlays/morph.nix) ]; };
  lib = pkgs.lib;
  stdenv = pkgs.stdenv;

in stdenv.mkDerivation rec {
  name = "vpsfree-cz-configuration";

  buildInputs = with pkgs; [
    git
    morph
  ];
}
