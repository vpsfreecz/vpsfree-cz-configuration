{ config, pkgs, lib, data, ... }:
let
  images = import ../../images.nix { inherit config data lib pkgs; };
  sshKeys = import ../../ssh-keys.nix;
in
{
  imports = [
    ../../env.nix
  ];

  system.monitoring.enable = true;

  services.netboot = {
    enable = true;
    host = "boot.vpsadminos.org";
    acmeSSL = true;
    vpsadminosItems = {};
    inherit (images) nixosItems;
  };

  services.vpsadminos-web = {
    enable = true;
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
