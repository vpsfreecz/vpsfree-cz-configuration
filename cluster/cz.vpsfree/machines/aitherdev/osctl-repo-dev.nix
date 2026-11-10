{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.osctl-repo-dev;
  host = "images.aitherdev.int.vpsfree.cz";
  tlsDirectory = "/var/lib/osctl-repo-dev/tls";
  reconcile = pkgs.writeShellApplication {
    name = "osctl-repo-dev-certificate";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      findutils
      getent
      gnugrep
      gnused
      openssl
      util-linux
    ];
    text = builtins.readFile ./osctl-repo-dev-certificate.bash;
  };
  certificateCommand = lib.escapeShellArgs [
    "${reconcile}/bin/osctl-repo-dev-certificate"
    config.services.dev-workspaces.tls.caStateDirectory
    tlsDirectory
    config.services.dev-workspaces.lockFile
    config.services.nginx.group
    host
    "90"
    "2592000"
  ];
in
{
  options.services.osctl-repo-dev = {
    enable = lib.mkEnableOption "the development image repository front door";
    backendPort = lib.mkOption {
      type = lib.types.port;
      default = 19485;
      description = "Host loopback port of an explicitly owned session SSH forward. Availability must be checked before binding.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.dev-workspaces.enable;
        message = "osctl-repo-dev requires the existing development workspace CA substrate";
      }
    ];

    systemd.tmpfiles.rules = [
      "d /var/lib/osctl-repo-dev 0750 root ${config.services.nginx.group} - -"
    ];
    systemd.services.osctl-repo-dev-certificate = {
      description = "Prepare the separate development image repository TLS leaf";
      before = [ "nginx.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
        TimeoutStartSec = "2min";
      };
      script = certificateCommand;
    };
    systemd.services.nginx = {
      requires = [ "osctl-repo-dev-certificate.service" ];
      after = [ "osctl-repo-dev-certificate.service" ];
    };
    systemd.services.osctl-repo-dev-certificate-renewal = {
      description = "Renew the separate development image repository TLS leaf";
      after = [ "nginx.service" ];
      serviceConfig = {
        Type = "oneshot";
        UMask = "0077";
        TimeoutStartSec = "2min";
      };
      script = ''
        ${certificateCommand}
        ${pkgs.systemd}/bin/systemctl reload nginx.service
      '';
    };
    systemd.timers.osctl-repo-dev-certificate-renewal = {
      description = "Check the development image repository TLS leaf daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Existing private/VPN firewall policy and listen address remain authoritative.
    services.nginx.virtualHosts.${host} = {
      forceSSL = true;
      listen = [
        {
          addr = config.services.dev-workspaces.listenAddress;
          port = 80;
        }
        {
          addr = config.services.dev-workspaces.listenAddress;
          port = 443;
          ssl = true;
        }
      ];
      sslCertificate = "${tlsDirectory}/current/server.pem";
      sslCertificateKey = "${tlsDirectory}/current/server-key.pem";
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.backendPort}";
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_cache off;
          gzip off;
          proxy_read_timeout 1h;
          proxy_set_header Connection "";
          proxy_set_header Accept-Encoding "";
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Repo-Client-IP $remote_addr;
          proxy_set_header Range $http_range;
          proxy_set_header If-Range $http_if_range;
          proxy_set_header If-Modified-Since $http_if_modified_since;
          proxy_set_header If-None-Match $http_if_none_match;
        '';
      };
    };
  };
}
