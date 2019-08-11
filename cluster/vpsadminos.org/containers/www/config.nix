{ config, pkgs, lib, confLib, data, ... }:
let
  images = import ../../../../images.nix { inherit config data lib confLib pkgs; };
in
{
  imports = [
    ../../../../environments/base.nix
  ];

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
