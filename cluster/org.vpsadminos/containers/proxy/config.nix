{ config, pkgs, lib, confLib, ... }:
let
  cache = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/int.cache";
  };

  images = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/int.images";
  };

  iso = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/int.iso";
  };

  www = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/int.www";
  };

  bbmaster = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/int.bb.master";
  };
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking = {
    firewall.allowedTCPPorts = [
      80 443 # nginx
    ];
  };

  environment.systemPackages = with pkgs; [
    apacheHttpd # for htpasswd
  ];

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

      "master.bb.vpsadminos.org" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/bbmaster.htpasswd";
        locations =
          let
            target = "http://${bbmaster.services.buildbot-master.address}:${toString bbmaster.services.buildbot-master.port}";
          in {
            "/".proxyPass = target;
            "/sse".extraConfig = ''
              proxy_buffering off;
              proxy_pass ${target}/sse/;
            '';
            "/ws".extraConfig = ''
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
              proxy_pass ${target}/ws;
              proxy_read_timeout 6000s;
            '';
            "/change_hook".extraConfig = ''
              auth_basic secured;
              auth_basic_user_file /private/nginx/bbgithub.htpasswd;
              proxy_pass ${target}/change_hook/github;
            '';
          };
      };
    };
  };
}
