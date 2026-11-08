{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.vpsfree-static-blog;
  state = "/var/lib/blog";
  portAllowed =
    firewall:
    lib.elem 8080 firewall.allowedTCPPorts
    || lib.any (range: range.from <= 8080 && range.to >= 8080) firewall.allowedTCPPortRanges;
  publication = cfg.publication;
  runtimePath =
    value:
    value != null
    && lib.hasPrefix "/" value
    && !(lib.hasPrefix "${builtins.storeDir}/" value)
    && !(lib.elem ".." (lib.splitString "/" value));
  policy = pkgs.writeText "blog-release-policy.json" (
    builtins.toJSON {
      schema = 2;
      authority = "hmac-upload-v1";
      implementation_sha256 = builtins.hashString "sha256" (
        builtins.readFile ../../../../tools/blog-static-release.py
        + builtins.readFile ../../../../tools/blog-upload.py
      );
      repository = "vpsfreecz/blog";
      workflow_path = ".github/workflows/build.yml";
      state_dir = state;
      enabled = cfg.enable && publication.enable;
      keep_releases = cfg.retention.keepReleases;
    }
  );
  source = pkgs.runCommand "blog-publication-source" { } ''
    mkdir -p "$out"
    substitute ${../../../../tools/blog-static-release.py} "$out/blog-static-release.py" \
      --replace-fail '@blogPolicy@' '${policy}'
    cp ${../../../../tools/blog-upload.py} "$out/blog-upload.py"
  '';
  helper = pkgs.writeShellApplication {
    name = "blog-static-release";
    runtimeInputs = [ pkgs.python3 ];
    text = ''exec python3 ${source}/blog-static-release.py "$@"'';
  };
  vhost = language: {
    extraConfig = "absolute_redirect off;";
    listen = [
      {
        addr = "127.0.0.1";
        port = 8080;
      }
    ];
    root = "${state}/current/${language}";
    locations."/".tryFiles = "$uri $uri/ =404";
    locations."= /feed/" = {
      # Select a regular-file URI before nginx's slash-URI index phase.
      tryFiles = "/feed/index.xml =404";
      extraConfig = ''
        types { }
        default_type application/rss+xml;
      '';
    };
    locations."/css/".tryFiles = "$uri @retained-blog-css";
    locations."@retained-blog-css" = {
      root = "${state}/assets";
      tryFiles = "$uri =404";
    };
    locations."~* \\.php(?:/|$)".return = "404";
  };
in
{
  options.services.vpsfree-static-blog = {
    enable = lib.mkEnableOption "the isolated static blog listener and storage";
    retention.keepReleases = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Newest successfully selected release payloads to retain, in addition to protected recovery references.";
    };
    sourcePackage = lib.mkOption {
      type = lib.types.package;
      internal = true;
      readOnly = true;
      default = source;
    };
    publication = {
      enable = lib.mkEnableOption "operator-controlled signed upload publication";
      secretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "External root-owned deployment HMAC key supplied through LoadCredential.";
      };
    };

  };
  config = lib.mkMerge [
    {
      environment.etc."blog-release-policy.json".source = policy;
      # Deliberately present even when this candidate disables the module.
      system.preSwitchChecks.blog-publication-maintenance = ''
        ${helper}/bin/blog-static-release check-maintenance
      '';
      assertions = [
        {
          assertion = !publication.enable || cfg.enable;
          message = "Blog publication requires static hosting.";
        }
      ];
    }
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.networking.firewall.enable && config.networking.firewall.backend == "iptables";
          message = "Static blog candidate requires the existing proxy-only iptables firewall.";
        }
        {
          assertion =
            !(portAllowed config.networking.firewall)
            && !(lib.any portAllowed (lib.attrValues config.networking.firewall.interfaces));
          message = "Static blog port 8080 must never be opened broadly.";
        }
      ]
      ++ [
        {
          assertion = !publication.enable || (runtimePath publication.secretFile);
          message = "Blog publication requires an external runtime deployment key.";
        }
      ];
      users.groups.blog-release = { };
      users.users.blog-release = {
        isSystemUser = true;
        group = "blog-release";
        home = state;
      };
      systemd.tmpfiles.rules = [
        "d ${state} 0755 blog-release blog-release -"
        "d ${state}/releases 0755 blog-release blog-release -"
        "d ${state}/receipts 0700 blog-release blog-release -"
        "d ${state}/assets 0755 blog-release blog-release -"
      ]
      ++ lib.optionals publication.enable [
        "d /var/lib/blog-control 0750 root blog-release -"
        "f /var/lib/blog-control/transaction.lock 0660 root blog-release -"
      ];
      environment.systemPackages = [ helper ];
      systemd.services.blog-release-prune = lib.mkIf publication.enable {
        description = "Retire old completed blog release payloads";
        serviceConfig = {
          Type = "oneshot";
          User = "blog-release";
          Group = "blog-release";
          UMask = "0077";
          ExecStart = "${helper}/bin/blog-static-release prune";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateNetwork = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [
            state
            "/var/lib/blog-control/transaction.lock"
          ];
          RestrictAddressFamilies = [ "AF_UNIX" ];
        };
      };
      systemd.timers.blog-release-prune = lib.mkIf publication.enable {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
      services.nginx.virtualHosts = {
        "static-blog-cs" = (vhost "cs") // {
          serverName = "blog.vpsfree.cz";
        };
        "static-blog-en" = (vhost "en") // {
          serverName = "blog.vpsfree.org";
        };
        "static-blog-unknown-host" = {
          serverName = "_";
          default = true;
          listen = [
            {
              addr = "127.0.0.1";
              port = 8080;
            }
          ];
          locations."/".return = "444";
        };
      };

    })
  ];
}
