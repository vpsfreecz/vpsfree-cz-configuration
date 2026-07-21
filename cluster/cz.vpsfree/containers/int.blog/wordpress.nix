{
  config,
  lib,
  pkgs,
  confLib,
  ...
}:

let
  siteName = "blog.vpsfree.cz";
  poolName = "wordpress-${siteName}";
  siteStateDir = "/var/lib/wordpress/${siteName}";
  secretKeysFile = "${siteStateDir}/secret-keys.php";
  uploadsDir = "${siteStateDir}/uploads";
  fontsDir = "${uploadsDir}/fonts";

  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  blogPackages = import ./packages { inherit pkgs; };

  wpRoot = "${config.services.wordpress.sites.${siteName}.finalPackage}/share/wordpress";

  wpCliIsolation = pkgs.runCommand "wp-blog-cli-isolation" { } ''
    mkdir -p \
      "$out/home" \
      "$out/config" \
      "$out/cache" \
      "$out/data" \
      "$out/packages" \
      "$out/work"
    touch "$out/config.yml" "$out/work/wp-cli.local.yml"
  '';

  wpBlogImpl = pkgs.writeShellApplication {
    name = "wp-blog-impl";
    text = ''
      for argument in "$@"; do
        case "$argument" in
          --path|--path=*|--no-path \
            |--ssh|--ssh=*|--no-ssh \
            |--http|--http=*|--no-http \
            |--url|--url=*|--no-url \
            |--blog|--blog=*|--no-blog \
            |--require|--require=*|--no-require \
            |--exec|--exec=*|--no-exec \
            |--config|--config=*|--no-config)
            printf 'wp-blog: refusing alternate WordPress target argument %q\n' \
              "$argument" >&2
            exit 64
            ;;
        esac
      done

      cd ${lib.escapeShellArg "${wpCliIsolation}/work"}
      exec ${pkgs.coreutils}/bin/env -i \
        HOME=${lib.escapeShellArg "${wpCliIsolation}/home"} \
        XDG_CONFIG_HOME=${lib.escapeShellArg "${wpCliIsolation}/config"} \
        XDG_CACHE_HOME=${lib.escapeShellArg "${wpCliIsolation}/cache"} \
        XDG_DATA_HOME=${lib.escapeShellArg "${wpCliIsolation}/data"} \
        WP_CLI_CONFIG_PATH=${lib.escapeShellArg "${wpCliIsolation}/config.yml"} \
        WP_CLI_PACKAGES_DIR=${lib.escapeShellArg "${wpCliIsolation}/packages"} \
        WP_CLI_CACHE_DIR=${lib.escapeShellArg "${wpCliIsolation}/cache"} \
        WP_CLI_STRICT_ARGS_MODE=1 \
        LANG=C.UTF-8 \
        LC_ALL=C.UTF-8 \
        PATH=${
          lib.escapeShellArg (
            lib.makeBinPath [
              pkgs.coreutils
              config.services.mysql.package
            ]
          )
        } \
        ${pkgs.wp-cli}/bin/wp --path=${lib.escapeShellArg wpRoot} "$@"
    '';
  };

  # Bash privileged mode ignores BASH_ENV and imported shell functions. The
  # outer launcher then clears the inherited environment before the checked
  # implementation parses any caller-controlled argument.
  wpBlog = pkgs.writeScriptBin "wp-blog" ''
    #!${pkgs.bash}/bin/bash -p
    exec ${pkgs.coreutils}/bin/env -i ${wpBlogImpl}/bin/wp-blog-impl "$@"
  '';

  wpBlogCoreUpdateDb = pkgs.writeScriptBin "wp-blog-core-update-db" ''
    #!${pkgs.bash}/bin/bash -p
    exec ${pkgs.coreutils}/bin/env -i \
      ${wpBlog}/bin/wp-blog \
      --skip-plugins \
      --skip-themes \
      core update-db "$@"
  '';

  secretHealthCheck = pkgs.writeShellApplication {
    name = "wordpress-blog-secret-health-check";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.php
    ];
    text = ''
      set -o nounset
      umask 0077

      readonly state_dir=${lib.escapeShellArg siteStateDir}
      readonly secret_file=${lib.escapeShellArg secretKeysFile}
      readonly uploads_dir=${lib.escapeShellArg uploadsDir}
      readonly fonts_dir=${lib.escapeShellArg fontsDir}
      readonly -a expected_keys=(
        AUTH_KEY
        SECURE_AUTH_KEY
        LOGGED_IN_KEY
        NONCE_KEY
        AUTH_SALT
        SECURE_AUTH_SALT
        LOGGED_IN_SALT
        NONCE_SALT
      )

      fail() {
        printf 'WordPress secret health: %s\n' "$*" >&2
        exit 1
      }

      [[ "$(id --user)" == 0 ]] || fail "must run as root"
      expected_uid="$(id --user wordpress)"
      expected_gid="$(id --group wordpress)"

      [[ -d "$state_dir" && ! -L "$state_dir" ]] \
        || fail "state directory is absent, a symlink, or not a directory"
      [[ "$(stat --format=%u:%g:%a -- "$state_dir")" \
        == "$expected_uid:$expected_gid:750" ]] \
        || fail "state directory has unsafe owner or mode"

      for mutable_directory in "$uploads_dir" "$fonts_dir"; do
        [[ -d "$mutable_directory" && ! -L "$mutable_directory" ]] \
          || fail "mutable directory is absent, a symlink, or not a directory: $mutable_directory"
        [[ "$(stat --format=%u:%g:%a -- "$mutable_directory")" \
          == "$expected_uid:$expected_gid:750" ]] \
          || fail "mutable directory has unsafe owner or mode: $mutable_directory"
      done

      [[ -f "$secret_file" && ! -L "$secret_file" ]] \
        || fail "secret key file is absent, a symlink, or not a regular file"
      [[ "$(stat --format=%u:%g:%a -- "$secret_file")" \
        == "$expected_uid:$expected_gid:440" ]] \
        || fail "secret key file has unsafe owner or mode"
      [[ "$(stat --format=%h -- "$secret_file")" == 1 ]] \
        || fail "secret key file has an unexpected hard-link count"

      mapfile -t lines < "$secret_file"
      [[ "''${#lines[@]}" == 10 ]] \
        || fail "secret key file has an unexpected line count"
      [[ "''${lines[0]}" == '<?php' && "''${lines[9]}" == '?>' ]] \
        || fail "secret key file has an unexpected wrapper"

      declare -A seen_values=()
      for index in "''${!expected_keys[@]}"; do
        key="''${expected_keys[index]}"
        line="''${lines[index + 1]}"
        pattern="^define\\('$key', '([A-Za-z0-9]{64})'\\);$"

        [[ "$line" =~ $pattern ]] \
          || fail "secret key definition $key is absent, duplicated, or malformed"
        value="''${BASH_REMATCH[1]}"
        [[ ! -v "seen_values[$value]" ]] \
          || fail "secret key values are not unique"
        seen_values["$value"]=1
      done

      unset value line lines
      ${pkgs.php}/bin/php -n --syntax-check "$secret_file" >/dev/null 2>&1 \
        || fail "secret key file is not valid PHP"
    '';
  };

  localHealthCheck = pkgs.writeShellApplication {
    name = "wordpress-blog-local-health-check";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      set -o nounset

      readonly host=${lib.escapeShellArg siteName}
      readonly base=http://127.0.0.1

      request_status() {
        local path="$1"

        curl \
          --silent \
          --show-error \
          --max-time 10 \
          --output /dev/null \
          --write-out '%{http_code}' \
          --header "Host: $host" \
          --header 'X-Forwarded-Proto: https' \
          "$base$path"
      }

      require_status() {
        local expected="$1"
        local path="$2"
        local actual

        actual="$(request_status "$path")"
        if [[ "$actual" != "$expected" ]]; then
          printf 'unexpected local HTTP status for %q: wanted %s, got %s\n' \
            "$path" "$expected" "$actual" >&2
          exit 1
        fi
      }

      require_status 200 /
      require_status 200 /feed/

      for forbidden_path in \
        /.health-check.php \
        /wp-content/files/health-check.php \
        /wp-content/fonts/health-check.php \
        /wp-content/uploads/health-check.php
      do
        require_status 403 "$forbidden_path"
      done

      for denied_path in \
        /wp-config.php \
        /wp-cron.php \
        /xmlrpc.php \
        /wp-trackback.php \
        /backups \
        /backups/health-check.sql.gz \
        /result \
        /result/health-check \
        /wordpress \
        /wordpress/health-check \
        /health-check.orig \
        /health-check.zip \
        '/health-check~'
      do
        require_status 404 "$denied_path"
      done

      core_version="$(${wpBlog}/bin/wp-blog --skip-plugins --skip-themes core version)"
      if [[ "$core_version" != 7.0.2 ]]; then
        printf 'unexpected WordPress core version: %s\n' "$core_version" >&2
        exit 1
      fi

      database_version="$(${wpBlog}/bin/wp-blog --skip-plugins --skip-themes option get db_version)"
      if [[ "$database_version" != 61833 ]]; then
        printf 'unexpected WordPress database version: %s\n' "$database_version" >&2
        exit 1
      fi

      if ${wpBlog}/bin/wp-blog --skip-plugins --skip-themes \
        option get wordpress_api_key >/dev/null 2>&1
      then
        printf 'compromised wordpress_api_key option is still present\n' >&2
        exit 1
      fi

      default_ping_status="$(${wpBlog}/bin/wp-blog --skip-plugins --skip-themes option get default_ping_status)"
      if [[ "$default_ping_status" != closed ]]; then
        printf 'default_ping_status is not closed: %s\n' "$default_ping_status" >&2
        exit 1
      fi

      default_pingback_flag="$(${wpBlog}/bin/wp-blog --skip-plugins --skip-themes option get default_pingback_flag)"
      if [[ "$default_pingback_flag" != 0 ]]; then
        printf 'default_pingback_flag is not disabled: %s\n' "$default_pingback_flag" >&2
        exit 1
      fi

      ping_sites="$(${wpBlog}/bin/wp-blog --skip-plugins --skip-themes option get ping_sites)"
      if [[ -n "$ping_sites" ]]; then
        printf 'outbound ping targets are still configured\n' >&2
        exit 1
      fi

    '';
  };

  tcpPortIsBroadlyAllowed =
    port:
    let
      rangeContains = range: range.from <= port && port <= range.to;
      permits =
        firewallConfig:
        lib.elem port firewallConfig.allowedTCPPorts
        || lib.any rangeContains firewallConfig.allowedTCPPortRanges;
    in
    permits config.networking.firewall
    || lib.any permits (lib.attrValues config.networking.firewall.interfaces);

in
{
  assertions = [
    {
      assertion = config.networking.firewall.enable;
      message = "blog.vpsfree.cz requires the firewall to protect proxy-header trust";
    }
    {
      assertion = config.networking.nftables.enable == false;
      message = "blog.vpsfree.cz requires the reviewed iptables firewall backend";
    }
    {
      assertion = config.networking.firewall.backend == "iptables";
      message = "blog.vpsfree.cz SMTP and proxy rules require networking.firewall.backend = iptables";
    }
    {
      assertion = !(tcpPortIsBroadlyAllowed 80);
      message = "blog.vpsfree.cz TCP/80 must not be opened broadly; only the exact proxy IPv4 rule is allowed";
    }
    {
      assertion = !(tcpPortIsBroadlyAllowed 3306);
      message = "blog.vpsfree.cz MariaDB is Unix-socket-only; TCP/3306 must remain closed";
    }
    {
      assertion =
        builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+" proxyPrg.addresses.primary.address != null;
      message = "blog.vpsfree.cz requires an IPv4 primary address for the prg proxy metadata";
    }
    {
      assertion = config.services.mail.sendmailSetuidWrapper == null;
      message = "blog.vpsfree.cz production must have no sendmail wrapper";
    }
    {
      assertion = config.services.mailpit.instances == { };
      message = "blog.vpsfree.cz production must have no Mailpit instance";
    }
    {
      assertion =
        !config.services.postfix.enable
        && !config.services.exim.enable
        && !config.services.opensmtpd.enable
        && !config.services.nullmailer.enable
        && !config.services.maddy.enable
        && !config.services.stalwart.enable;
      message = "blog.vpsfree.cz production must not enable an MTA";
    }
  ];

  networking.firewall.enable = true;
  networking.nftables.enable = false;

  networking.firewall.extraCommands = ''
    # Accept backend HTTP only from the production proxy's exact IPv4.
    iptables -w -A nixos-fw -p tcp \
      -s ${proxyPrg.addresses.primary.address}/32 --dport 80 \
      -j nixos-fw-accept

    # Fail closed for external SMTP from the WordPress Unix user.
    while iptables -w -D OUTPUT -j vpsf-blog-smtp4 2>/dev/null; do :; done
    iptables -w -N vpsf-blog-smtp4 2>/dev/null || true
    iptables -w -F vpsf-blog-smtp4
    iptables -w -A vpsf-blog-smtp4 -p tcp \
      -m owner --uid-owner wordpress ! -d 127.0.0.0/8 \
      -m multiport --dports 25,465,587 \
      -j REJECT --reject-with tcp-reset
    iptables -w -I OUTPUT 1 -j vpsf-blog-smtp4

    while ip6tables -w -D OUTPUT -j vpsf-blog-smtp6 2>/dev/null; do :; done
    ip6tables -w -N vpsf-blog-smtp6 2>/dev/null || true
    ip6tables -w -F vpsf-blog-smtp6
    ip6tables -w -A vpsf-blog-smtp6 -p tcp \
      -m owner --uid-owner wordpress ! -d ::1/128 \
      -m multiport --dports 25,465,587 \
      -j REJECT --reject-with tcp-reset
    ip6tables -w -I OUTPUT 1 -j vpsf-blog-smtp6
  '';

  networking.firewall.extraStopCommands = ''
    while iptables -w -D OUTPUT -j vpsf-blog-smtp4 2>/dev/null; do :; done
    iptables -w -F vpsf-blog-smtp4 2>/dev/null || true
    iptables -w -X vpsf-blog-smtp4 2>/dev/null || true
    while ip6tables -w -D OUTPUT -j vpsf-blog-smtp6 2>/dev/null; do :; done
    ip6tables -w -F vpsf-blog-smtp6 2>/dev/null || true
    ip6tables -w -X vpsf-blog-smtp6 2>/dev/null || true
  '';

  services.mysql.settings.mysqld."skip-networking" = true;

  services.wordpress = {
    webserver = "nginx";

    sites.${siteName} = {
      package = blogPackages.wordpress;
      inherit (blogPackages) plugins themes languages;
      inherit uploadsDir;
      # Keep the module's second mutable tree inside the site's uploads tree.
      inherit fontsDir;

      database = {
        createLocally = true;
        host = "localhost";
        socket = "/run/mysqld/mysqld.sock";
        name = "wordpress";
        user = "wordpress";
        tablePrefix = "wp_";
      };

      settings = {
        WP_HOME = "https://${siteName}";
        WP_SITEURL = "https://${siteName}";
        FORCE_SSL_ADMIN = true;
        DISABLE_WP_CRON = true;
        DISALLOW_FILE_MODS = true;
        WP_HTTP_BLOCK_EXTERNAL = true;
        WPLANG = "cs_CZ";
        WP_DEFAULT_THEME = "twentytwentyfive";
        WP_ENVIRONMENT_TYPE = "production";
      };

      extraConfig = ''
        if (isset($_SERVER['HTTP_X_FORWARDED_PROTO'])
            && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
          $_SERVER['HTTPS'] = 'on';
        }
      '';
    };
  };

  services.nginx = {
    enableReload = true;

    virtualHosts.${siteName} = {
      # The public proxy terminates TLS; this backend has one IPv4 HTTP
      # listener and no ACME, TLS, or IPv6 HTTP listener.
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
      ];
      enableACME = false;
      addSSL = false;
      forceSSL = false;

      extraConfig = ''
        # The production proxy overwrites X-Real-IP with its directly
        # observed client. Trust that single header only on connections
        # from the metadata-resolved proxy /32; never consume an
        # arbitrary X-Forwarded-For chain.
        set_real_ip_from ${proxyPrg.addresses.primary.address}/32;
        real_ip_header X-Real-IP;
        real_ip_recursive off;
      '';

      locations = {
        "= /wp-config.php".extraConfig = "return 404;";
        "= /wp-cron.php".extraConfig = "return 404;";
        "= /xmlrpc.php".extraConfig = "return 404;";
        "= /wp-trackback.php".extraConfig = "return 404;";

        "= /backups".extraConfig = "return 404;";
        "^~ /backups/".extraConfig = "return 404;";
        "= /result".extraConfig = "return 404;";
        "^~ /result/".extraConfig = "return 404;";
        "= /wordpress".extraConfig = "return 404;";
        "^~ /wordpress/".extraConfig = "return 404;";

        # Nginx uses the first matching regex location. Force dotfiles and
        # every PHP path below writable WordPress trees ahead of the
        # module's generic PHP/FastCGI regex.
        "~ /\\.".priority = lib.mkForce 300;
        "~* ^/wp-content/(?:uploads|fonts|files)/.*\\.php$" = {
          priority = 400;
          extraConfig = "deny all;";
        };

        "~* (?:~|\\.(?:bak|backup|old|orig|phpb|rar|save|sql(?:\\.(?:bz2|gz|xz))?|tar(?:\\.(?:bz2|gz|xz))?|tbz2?|tgz|txz|zip|7z))$".extraConfig =
          "return 404;";
      };
    };
  };

  environment.systemPackages = [
    wpBlog
    wpBlogCoreUpdateDb
    secretHealthCheck
    localHealthCheck
  ];

  systemd.services."phpfpm-${poolName}" = {
    requires = [ "wordpress-blog-secret-health-check.service" ];
    after = [ "wordpress-blog-secret-health-check.service" ];
  };

  systemd.services.wordpress-blog-secret-health-check = {
    description = "Validate persistent WordPress secrets for ${siteName}";
    requires = [ "wordpress-init-${siteName}.service" ];
    after = [ "wordpress-init-${siteName}.service" ];
    before = [
      "phpfpm-${poolName}.service"
      "wordpress-cron-${siteName}.service"
      "wordpress-blog-local-health-check.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = config.services.nginx.group;
      UMask = "0077";
      ExecStart = "${secretHealthCheck}/bin/wordpress-blog-secret-health-check";
      PrivateNetwork = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      CapabilityBoundingSet = "";
    };
  };

  systemd.services."wordpress-cron-${siteName}" = {
    description = "Run due WordPress cron events for ${siteName}";
    requisite = [ "mysql.service" ];
    requires = [ "wordpress-blog-secret-health-check.service" ];
    after = [
      "mysql.service"
      "wordpress-blog-secret-health-check.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "wordpress";
      Group = config.services.nginx.group;
      UMask = "0077";
      ExecStart = "${wpBlog}/bin/wp-blog cron event run --due-now";
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };

  systemd.timers."wordpress-cron-${siteName}" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      Unit = "wordpress-cron-${siteName}.service";
      OnCalendar = "*-*-* *:0/5:00";
      Persistent = false;
      RandomizedDelaySec = "0";
      AccuracySec = "1s";
    };
  };

  systemd.services.wordpress-blog-local-health-check = {
    description = "Check local WordPress and denial paths for ${siteName}";
    requires = [ "wordpress-blog-secret-health-check.service" ];
    requisite = [
      "mysql.service"
      "nginx.service"
      "phpfpm-${poolName}.service"
    ];
    after = [
      "mysql.service"
      "nginx.service"
      "phpfpm-${poolName}.service"
      "wordpress-blog-secret-health-check.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "wordpress";
      Group = config.services.nginx.group;
      ExecStart = "${localHealthCheck}/bin/wordpress-blog-local-health-check";
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };
}
