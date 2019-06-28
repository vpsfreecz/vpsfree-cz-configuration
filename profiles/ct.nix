{ config, ... }:

let
  pkgs = import <nixpkgs> {};
  pinned = import ../pinned.nix { inherit (pkgs) lib; inherit pkgs; };
in
{
  imports = [
    <nixpkgs/nixos/modules/virtualisation/container-config.nix>
    "${pinned.vpsadminosSrc}/os/lib/nixos-container/build.nix"
    "${pinned.vpsadminosSrc}/os/lib/nixos-container/networking.nix"
  ];

  services.resolved.enable = false;
}
