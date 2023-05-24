{ pkgs, lib, config, confLib, ... }:
let
  alerts1Prg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.alerts1";
  };

  alerts2Prg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.alerts2";
  };

  mon1Prg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.mon1";
  };

  mon2Prg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.mon2";
  };

  grafanaPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.grafana";
  };

  rubygems = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.rubygems";
  };

  vpsfbot = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.vpsfbot";
  };

  paste = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.paste";
  };

  utils = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.utils";
  };
in {
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
    ../../../vpsadmin/common/all.nix
    ../../../vpsadmin/common/frontend.nix
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
      "alerts1.prg.vpsfree.cz" = {
        serverAliases = [ "alerts.prg.vpsfree.cz" ];
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/alerts.htpasswd";
        locations."/".proxyPass = "http://${alerts1Prg.services.alertmanager.address}:${toString alerts1Prg.services.alertmanager.port}";
      };

      "alerts2.prg.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/alerts.htpasswd";
        locations."/".proxyPass = "http://${alerts2Prg.services.alertmanager.address}:${toString alerts2Prg.services.alertmanager.port}";
      };

      "mon1.prg.vpsfree.cz" = {
        serverAliases = [ "mon.prg.vpsfree.cz" ];
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/mon.htpasswd";
        locations."/".proxyPass = "http://${mon1Prg.services.prometheus.address}:${toString mon1Prg.services.prometheus.port}";
      };

      "mon2.prg.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/mon.htpasswd";
        locations."/".proxyPass = "http://${mon2Prg.services.prometheus.address}:${toString mon2Prg.services.prometheus.port}";
      };

      "grafana.prg.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${grafanaPrg.services.grafana.address}:${toString grafanaPrg.services.grafana.port}";
      };

      "rubygems.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${rubygems.services.geminabox.address}:${toString rubygems.services.geminabox.port}";
      };

      "vpsfbot.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/gh-webhook".proxyPass = "http://${vpsfbot.addresses.primary.address}:8000";
      };

      "bepasty.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${paste.services.bepasty.address}:${toString paste.services.bepasty.port}";
      };

      "utils.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/mon.htpasswd";
        locations."/".proxyPass = "http://${utils.addresses.primary.address}:80";
      };
    };
  };

  system.stateVersion = "22.05";
}
