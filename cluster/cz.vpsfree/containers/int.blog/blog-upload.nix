{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.vpsfree-static-blog;
  source = cfg.sourcePackage;
  helper = pkgs.writeShellApplication {
    name = "blog-upload";
    runtimeInputs = [ pkgs.python3 ];
    text = ''exec python3 ${source}/blog-upload.py "$@"'';
  };
in
{
  config = lib.mkIf cfg.publication.enable {
    services.nginx.virtualHosts.blog-front-cs.locations."= /_deploy/blog" = {
      proxyPass = "http://127.0.0.1:8091";
      recommendedProxySettings = false;
      extraConfig = ''
        client_max_body_size 512m;
        client_body_timeout 180s;
        proxy_connect_timeout 5s;
        proxy_send_timeout 180s;
        proxy_read_timeout 180s;
        proxy_request_buffering on;
        proxy_buffering on;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host blog.vpsfree.cz;
        proxy_pass_request_headers on;
        proxy_pass_request_body on;
        access_log off;
        error_log /dev/null;
      '';
    };
    systemd.services.blog-upload = {
      description = "Validate and durably select signed blog uploads";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "systemd-tmpfiles-setup.service"
      ];
      serviceConfig = {
        User = "blog-release";
        Group = "blog-release";
        UMask = "0077";
        LoadCredential = [
          "deployment-key:${if cfg.publication.secretFile == null then "" else cfg.publication.secretFile}"
        ];
        ExecStart = "${helper}/bin/blog-upload --secret-file %d/deployment-key";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          "/var/lib/blog"
          "/var/lib/blog-control/transaction.lock"
        ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_UNIX"
        ];
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
