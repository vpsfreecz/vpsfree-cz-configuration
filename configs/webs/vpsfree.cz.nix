{ config, pkgs, ... }:
let
  source = pkgs.fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "web";
    rev = "2d55392daba502772076c65308a729eac9b93cbe";
    sha256 = "sha256-B/D7oicITsThDmtBkYpekdCfp78KstPrvvckRbU01xQ=";
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

  vhost = { domain, web, language }: {
    serverAliases = [ "www.${domain}" ];
    enableACME = false;
    forceSSL = false;
    root = "${web}/${language}/";
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
      alias ${web}/css/;
    '';
    locations."/js/".extraConfig = ''
      alias ${web}/js/;
    '';
    locations."/obrazky/".extraConfig = ''
      alias ${web}/obrazky/;
    '';
    locations."/download/".extraConfig = ''
      alias ${web}/download/;
    '';
  };
in {
  environment.systemPackages = with pkgs; [
    xz # For Slovak QR Payments
  ];

  services.nginx.virtualHosts = {
    "vpsfree.cz" = vhost {
      domain = "vpsfree.cz";
      inherit web;
      language = "cs";
    };

    "vpsfree.org" = vhost {
      domain = "vpsfree.cz";
      inherit web;
      language = "en";
    };

    "dev.vpsfree.cz" = vhost {
      domain = "dev.vpsfree.cz";
      web = "/var/www/dev.vpsfree.cz";
      language = "cs";
    };

    "dev.vpsfree.org" = vhost {
      domain = "dev.vpsfree.org";
      web = "/var/www/dev.vpsfree.cz";
      language = "en";
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