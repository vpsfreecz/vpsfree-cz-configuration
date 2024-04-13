{ config, pkgs, ... }:
let
  source = pkgs.fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "web";
    rev = "c3c31989257ffd407d244d65b0a1d0ad9671191f";
    sha256 = "sha256-1WgTX8RiszvVEsrWJ7YuAtzYVLW7/E8gKxQYUifpJjo=";
  };

  configFile = pkgs.writeText "vpsfree-config.php" ''
    <?php
    define ('API_URL', 'https://api.vpsfree.cz');
    define ('ENVIRONMENT_ID', 1);
  '';

  configured = pkgs.runCommand "vpsfree-web" {} ''
    mkdir $out
    cp -r ${source}/. $out/

    # NOTE: ln doesn't work properly, possibly due to composer2nix. The dependency
    # is not tracked by Nix and configFile is not copied to the target system.
    cp ${configFile} $out/config.php
  '';

  web = import configured { inherit pkgs; };

  vhost = { domain, root }: {
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
    "vpsfree.cz" = vhost {
      domain = "vpsfree.cz";
      root = "${web}/cs/";
    };

    "vpsfree.org" = vhost {
      domain = "vpsfree.cz";
      root = "${web}/en/";
    };

    "dev.vpsfree.cz" = vhost {
      domain = "dev.vpsfree.cz";
      root = "/var/www/dev.vpsfree.cz/cs/";
    };

    "dev.vpsfree.org" = vhost {
      domain = "dev.vpsfree.org";
      root = "/var/www/dev.vpsfree.cz/en/";
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