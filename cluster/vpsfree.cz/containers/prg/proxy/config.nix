{ pkgs, lib, config, confLib, ... }:
let
  alertsPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "vpsfree.cz";
    location = "prg";
    name = "alerts.int";
  };

  monPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "vpsfree.cz";
    location = "prg";
    name = "mon.int";
  };

  grafanaPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "vpsfree.cz";
    location = "prg";
    name = "grafana.int";
  };
in {
  imports = [
    ../../../../../environments/base.nix
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
      "alerts.prg.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/mon.htpasswd";
        locations."/".proxyPass = "http://${alertsPrg.services.alertmanager.address}:${toString alertsPrg.services.alertmanager.port}";
      };

      "mon.prg.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/mon.htpasswd";
        locations."/".proxyPass = "http://${monPrg.services.prometheus.address}:${toString monPrg.services.prometheus.port}";
      };

      "grafana.prg.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/mon.htpasswd";
        locations."/".proxyPass = "http://${grafanaPrg.services.grafana.address}:${toString grafanaPrg.services.grafana.port}";
      };
    };
  };
}
