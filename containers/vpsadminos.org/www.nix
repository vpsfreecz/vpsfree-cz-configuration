{ config, pkgs, lib, ... }:
let
  images = import ../../images.nix { inherit lib pkgs; };
  sshKeys = import ../../ssh-keys.nix;
in
{
  imports = [
    ../../env.nix
    # Not available on nixos-17.09
    # ../modules/monitored.nix
    ../../modules/netboot.nix
    ../../modules/web.nix
  ];

  netboot = {
    host = "boot.vpsadminos.org";
    acmeSSL = true;
    vpsadminosItems = {};
    inherit (images) nixosItems;
  };

  web = {
    acmeSSL = true;
    domain = "vpsadminos.org";
    isoImages = [ images.vpsadminosISO ];
  };

  deployment = {
    healthChecks = {
      http = [
        {
          scheme = "http";
          port = 80;
          path = "/";
          description = "Check whether nginx is running.";
        }
        {
          scheme = "https";
          port = 443;
          host = "vpsadminos.org";
          path = "/";
          description = "vpsadminos.org is up";
        }
      ];
    };
  };
}
