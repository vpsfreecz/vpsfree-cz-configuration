{ config, pkgs, lib, ... }:
let
  images = import ../images.nix { inherit lib pkgs; };
  sshKeys = import ../ssh-keys.nix;
in
{
  imports = [
    ../modules/netboot.nix
    ../modules/web.nix
  ];

  netboot = {
    host = "boot.vpsadminos.org";
    acmeSSL = true;
    vpsadminosItems = [];
    inherit (images) nixosItems mappings;
  };

  web = {
    acmeSSL = true;
    domain = "vpsadminos.org";
    isoImages = [ images.vpsadminosISO ];
  };
}
