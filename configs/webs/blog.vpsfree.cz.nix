{ config, pkgs, ... }:
{
  services.nginx.virtualHosts."blog.vpsfree.cz" = {
    enableACME = false;
    forceSSL = false;
    root = "/var/www/blog.vpsfree.cz";
    locations."~ \\.php$".extraConfig = ''
      try_files $uri =404;
      fastcgi_pass  unix:${config.services.phpfpm.pools.blog.socket};
    '';
    locations."= /backups".extraConfig = "return 404;";
    locations."^~ /backups/".extraConfig = "return 404;";
    locations."= /result".extraConfig = "return 404;";
    locations."^~ /result/".extraConfig = "return 404;";
    locations."= /wordpress".extraConfig = "return 404;";
    locations."^~ /wordpress/".extraConfig = "return 404;";
    locations."~* (?:~|\\.(?:bak|backup|old|orig|phpb|rar|save|sql(?:\\.(?:bz2|gz|xz))?|tar(?:\\.(?:bz2|gz|xz))?|tbz2?|tgz|txz|zip|7z))$".extraConfig =
      "return 404;";
    locations."/".extraConfig = ''
      try_files $uri $uri/ /index.php?$args;
      index index.php index.html;
    '';
  };

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  services.phpfpm.pools.blog = {
    user = "blog";
    group = "blog";

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

  vpsfconf.phpfpmSessionCleanup.pools = [ "blog" ];

  users = {
    users.blog = {
      isSystemUser = true;
      group = "blog";
      description = "vpsfree blog";
    };

    groups.blog = { };
  };
}
