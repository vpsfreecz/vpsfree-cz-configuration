{ config, pkgs, ... }:
let
  vpsfreeWeb = { domain, root }: {
    serverAliases = [ "www.${domain}" ];
    enableACME = false;
    forceSSL = false;
    inherit root;
    locations."~ \.php$".extraConfig = ''
      ssi on;
      gzip off;
      fastcgi_pass  unix:${config.services.phpfpm.pools.vpsfree.socket};
    '';
    locations."/".extraConfig = ''
      gzip off;
      ssi on;
    '';
    locations."/prihlaska/".extraConfig = ''
      gzip off;
      ssi on;
    '';
    locations."/css/".extraConfig = ''
      alias /var/www/vpsfree.cz/css/;
    '';
    locations."/js/".extraConfig = ''
      alias /var/www/vpsfree.cz/js/;
    '';
    locations."/obrazky/".extraConfig = ''
      alias /var/www/vpsfree.cz/obrazky/;
    '';
    locations."/download/".extraConfig = ''
      alias /var/www/vpsfree.cz/download/;
    '';
  };
in {
  environment.systemPackages = with pkgs; [
    xz # For Slovak QR Payments
  ];

  services.nginx.virtualHosts = {
    "vpsfree.cz" = vpsfreeWeb {
      domain = "vpsfree.cz";
      root = "/var/www/vpsfree.cz/cs/";
    };

    "vpsfree.org" = vpsfreeWeb {
      domain = "vpsfree.cz";
      root = "/var/www/vpsfree.cz/en/";
    };

    "dev.vpsfree.cz" = vpsfreeWeb {
      domain = "dev.vpsfree.cz";
      root = "/var/www/vpsfree.cz/cs/";
    };

    "dev.vpsfree.org" = vpsfreeWeb {
      domain = "dev.vpsfree.org";
      root = "/var/www/vpsfree.cz/en/";
    };
  };

  services.phpfpm.pools.vpsfree = {
    user = "vpsfree";
    group = "vpsfree";

    settings = {
      "pm" = "dynamic";
      "listen.owner" = config.services.nginx.user;
      "pm.max_children" = 5;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 3;
      "pm.max_requests" = 500;
    };
  };

  users = {
    users.vpsfree = {
      isSystemUser = true;
      group = "vpsfree";
      description = "vpsfree main web account";
    };

    groups.vpsfree = {};
  };
}