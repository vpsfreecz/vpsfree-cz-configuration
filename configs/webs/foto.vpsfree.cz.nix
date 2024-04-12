{ config, pkgs, ... }:
let
  nix-phps = pkgs.fetchFromGitHub {
    owner = "fossar";
    repo = "nix-phps";
    rev = "1bf10b8c3c378e14d11861a056e885775a2ebc73";
    hash = "sha256-mHmf8dyZM28LlFC4ccm6DE5R0NQlFaTr+W46vfZ1lmg=";
  };

  phps = import nix-phps;
in {
  services.nginx.virtualHosts."foto.vpsfree.cz" = {
    enableACME = false;
    forceSSL = false;
    root = "/var/www/foto.vpsfree.cz";
    locations."~ \.php$".extraConfig = ''
      fastcgi_pass  unix:${config.services.phpfpm.pools.foto.socket};
    '';
    locations."/".extraConfig = ''
      index index.php index.html;
    '';
  };

  services.phpfpm.pools.foto = {
    user = "foto";
    group = "foto";
    phpPackage = phps.packages.${builtins.currentSystem}.php56;

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
    users.foto = {
      isSystemUser = true;
      group = "vpsfree";
      description = "vpsfree photogallery";
    };

    groups.foto = {};
  };
}