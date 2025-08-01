{
  pkgs,
  lib,
  config,
  confLib,
  ...
}:
let
  alerts1Prg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.alerts1";
  };

  alerts2Prg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.alerts2";
  };

  mon1Prg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.mon1";
  };

  mon2Prg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.mon2";
  };

  grafanaPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.grafana";
  };

  rubygems = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.rubygems";
  };

  vpsfbot = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.vpsfbot";
  };

  paste = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.paste";
  };

  utils = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.utils";
  };

  kb = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.kb";
  };

  munin = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.munin";
  };

  web = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.web";
  };
in
{
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
    ../../../../../configs/goresheat-proxy.nix
    ../../../vpsadmin/common/all.nix
    ../../../vpsadmin/common/frontend.nix
  ];

  networking = {
    firewall.allowedTCPPorts = [
      80
      443 # nginx
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
      "vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        serverAliases = [ "www.vpsfree.cz" ];
        locations."/".proxyPass = "http://${web.addresses.primary.address}:80";
      };

      "vpsfree.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${web.addresses.primary.address}:80";
      };

      "alerts1.prg.vpsfree.cz" = {
        serverAliases = [ "alerts.prg.vpsfree.cz" ];
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/alerts.htpasswd";
        locations."/".proxyPass =
          "http://${alerts1Prg.services.alertmanager.address}:${toString alerts1Prg.services.alertmanager.port}";
      };

      "alerts2.prg.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/alerts.htpasswd";
        locations."/".proxyPass =
          "http://${alerts2Prg.services.alertmanager.address}:${toString alerts2Prg.services.alertmanager.port}";
      };

      "mon1.prg.vpsfree.cz" = {
        serverAliases = [ "mon.prg.vpsfree.cz" ];
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/mon.htpasswd";
        locations."/".proxyPass =
          "http://${mon1Prg.services.prometheus.address}:${toString mon1Prg.services.prometheus.port}";
      };

      "mon2.prg.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/mon.htpasswd";
        locations."/".proxyPass =
          "http://${mon2Prg.services.prometheus.address}:${toString mon2Prg.services.prometheus.port}";
      };

      "grafana.prg.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass =
          "http://${grafanaPrg.services.grafana.address}:${toString grafanaPrg.services.grafana.port}";
      };

      "rubygems.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass =
          "http://${rubygems.services.geminabox.address}:${toString rubygems.services.geminabox.port}";
      };

      "vpsfbot.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/discourse-webhook".proxyPass = "http://${vpsfbot.addresses.primary.address}:8001";
        locations."/gh-webhook".proxyPass = "http://${vpsfbot.addresses.primary.address}:8000";
      };

      "matterbridge.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${vpsfbot.addresses.primary.address}:80";
      };

      "paste.vpsfree.cz" = {
        serverAliases = [ "bepasty.vpsfree.cz" ];
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass =
          "http://${paste.services.bepasty.address}:${toString paste.services.bepasty.port}";
      };

      "utils.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/mon.htpasswd";
        locations."/".proxyPass = "http://${utils.addresses.primary.address}:80";
      };

      "kb.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${kb.addresses.primary.address}:80";
      };

      "kb.vpsfree.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${kb.addresses.primary.address}:80";
      };

      "munin.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${munin.addresses.primary.address}:80";
      };

      "prasiatko.vpsfree.cz" = {
        serverAliases = [
          "prasiatko.vpsfree.cz"
          "conference.vpsfree.cz"
          "piwik.vpsfree.cz"
        ];
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://37.205.15.53:80";
      };

      "blog.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${web.addresses.primary.address}:80";
      };

      "foto.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${web.addresses.primary.address}:80";
      };

      "lists.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://37.205.15.53:80";
      };

      "mirror.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://185.8.165.222:80";
      };

      "rt.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "https://172.16.9.194:443";
      };

      "web-dev.vpsfree.cz" = {
        locations."/".proxyPass = "http://${web.addresses.primary.address}:80";
      };

      "web-dev.vpsfree.org" = {
        locations."/".proxyPass = "http://${web.addresses.primary.address}:80";
      };
    };
  };

  system.stateVersion = "22.05";
}
