{ config, pkgs, lib, confLib, data, ... }:
let
  cache = confLib.findConfig {
    cluster = config.cluster;
    domain = "org.vpsadminos";
    location = null;
    name = "int.cache";
  };

  images = confLib.findConfig {
    cluster = config.cluster;
    domain = "org.vpsadminos";
    location = null;
    name = "int.images";
  };

  iso = confLib.findConfig {
    cluster = config.cluster;
    domain = "org.vpsadminos";
    location = null;
    name = "int.iso";
  };

  www = confLib.findConfig {
    cluster = config.cluster;
    domain = "org.vpsadminos";
    location = null;
    name = "int.www";
  };
in {
  imports = [
    ../../../../environments/base.nix
  ];

  networking = {
    firewall.allowedTCPPorts = [
      80 443 # nginx
    ];
  };

  services.nginx = {
    enable = true;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {
      "vpsadminos.org" = {
        serverAliases = [
          "www.vpsadminos.org"
          "ref.vpsadminos.org"
          "man.vpsadminos.org"
        ];
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${www.services.nginx.address}:${toString www.services.nginx.port}";
      };

      "images.vpsadminos.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${images.services.nginx.address}:${toString images.services.nginx.port}";
      };

      "iso.vpsadminos.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${iso.services.nginx.address}:${toString iso.services.nginx.port}";
      };

      "cache.vpsadminos.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${cache.services.nix-serve.address}:${toString cache.services.nix-serve.port}";
      };
    };
  };

  deployment = {
    healthChecks = {
      http = [
        {
          scheme = "http";
          port = 80;
          host = "proxy.vpsadminos.org";
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
