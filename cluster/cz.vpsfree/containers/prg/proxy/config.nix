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

  expectedProxyAcmeCertNames = [
    "alerts1.prg.vpsfree.cz"
    "alerts2.prg.vpsfree.cz"
    "api-admin.vpsfree.cz"
    "api.vpsfree.cz"
    "auth-admin.vpsfree.cz"
    "auth.vpsfree.cz"
    "blog.vpsfree.cz"
    "console-admin.vpsfree.cz"
    "console.vpsfree.cz"
    "download-admin.vpsfree.cz"
    "download.vpsfree.cz"
    "foto.vpsfree.cz"
    "goresheat.vpsfree.cz"
    "grafana.prg.vpsfree.cz"
    "kb.vpsfree.cz"
    "kb.vpsfree.org"
    "lists.vpsfree.cz"
    "matterbridge.vpsfree.cz"
    "mon1.prg.vpsfree.cz"
    "mon2.prg.vpsfree.cz"
    "munin.vpsfree.cz"
    "paste.vpsfree.cz"
    "prasiatko.vpsfree.cz"
    "rt.vpsfree.cz"
    "rubygems.vpsfree.cz"
    "utils.vpsfree.cz"
    "vpsadmin-admin.vpsfree.cz"
    "vpsadmin-dev.vpsfree.cz"
    "vpsadmin.vpsfree.cz"
    "vpsfbot.vpsfree.cz"
    "vpsfree.cz"
    "vpsfree.org"
  ];

  proxyAcmeCertNames = builtins.attrNames config.security.acme.certs;
  proxyAcmeServices = map (certName: "acme-${certName}.service") proxyAcmeCertNames;
  proxyAcmeOrderRenewServices = map (
    certName: "acme-order-renew-${certName}.service"
  ) proxyAcmeCertNames;
in
{
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
    ../../../../../configs/goresheat-proxy.nix
    ../../../vpsadmin/common/all.nix
    ../../../vpsadmin/common/frontend.nix
  ];

  assertions = [
    {
      assertion = proxyAcmeCertNames == expectedProxyAcmeCertNames;
      message = ''
        The temporary proxy reload transition expects the reviewed set of 32
        ACME certificates. Re-review its machine-local dependency shim before
        changing that set.
      '';
    }
  ];

  # vpsAdminOS intentionally masks this unit while the container host keeps
  # the debugfs mount active. The pinned switch tool otherwise treats the
  # unchanged mask as a removal and unmounts it on every switch. Keep this
  # proxy-local until nixpkgs carries an equivalent reviewed fix.
  nixpkgs.overlays = [
    (_final: previous: {
      switch-to-configuration-ng = previous.switch-to-configuration-ng.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./switch-to-configuration-preserve-debugfs.patch ];
      });
    })
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
    enableReload = true;

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

  # Native nginx reload mode moves the ACME dependency graph from nginx to
  # every certificate unit. Preserve the active graph during this migration
  # so the one-time transition cannot stop or start ACME services. The
  # generated nginx configuration and certificate behavior remain unchanged;
  # only nginx and its existing config-reload helper may act at switch time.
  systemd.services = {
    nginx = {
      wants = lib.mkForce proxyAcmeServices;
      after = lib.mkForce ([ "network.target" ] ++ proxyAcmeServices);
      before = lib.mkForce proxyAcmeOrderRenewServices;
    };

    nginx-config-reload = {
      wants = lib.mkForce [ "nginx.service" ];
      after = lib.mkForce [ "nginx.service" ];
      before = lib.mkForce [ ];
      wantedBy = lib.mkForce [ "multi-user.target" ];
    };
  }
  // lib.listToAttrs (
    map (
      certName:
      lib.nameValuePair "acme-${certName}" {
        before = lib.mkForce [ "acme-order-renew-${certName}.service" ];
        wantedBy = lib.mkForce [ "multi-user.target" ];
      }
    ) proxyAcmeCertNames
  );

  system.stateVersion = "22.05";
}
