{ pkgs, lib, config, confLib, ... }:
let
  alerts1Prg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.alerts1";
  };

  mon1Prg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.mon1";
  };

  grafanaPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.grafana";
  };
in {
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
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
        basicAuthFile = "/private/nginx/mon.htpasswd";
        locations."/".proxyPass = "http://${alerts1Prg.services.alertmanager.address}:${toString alerts1Prg.services.alertmanager.port}";
      };

      "mon1.prg.vpsfree.cz" = {
        serverAliases = [ "mon.prg.vpsfree.cz" ];
        enableACME = true;
        forceSSL = true;
        basicAuthFile = "/private/nginx/mon.htpasswd";
        locations."/".proxyPass = "http://${mon1Prg.services.prometheus.address}:${toString mon1Prg.services.prometheus.port}";
      };

      "grafana.prg.vpsfree.cz" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${grafanaPrg.services.grafana.address}:${toString grafanaPrg.services.grafana.port}";
      };
    };
  };
}
