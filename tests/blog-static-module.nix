{ nixpkgs }:
let
  lib = nixpkgs.lib;
  site = ../cluster/cz.vpsfree/containers/int.blog;
  # Exercise the site's imports without base profiles or machine publication opt-in.
  composition =
    { config, ... }:
    let
      module = import (site + /config.nix) { inherit config; };
    in
    module
    // {
      # Exercise reusable module defaults/modes; machine opt-in is checked separately.
      services = builtins.removeAttrs (module.services or { }) [ "vpsfree-static-blog" ];
      imports = builtins.filter (
        path:
        !(lib.elem path [
          ../environments/base.nix
          ../profiles/ct.nix
        ])
      ) module.imports;
    };
  evaluateAt =
    address: modules:
    (import "${nixpkgs}/nixos/lib/eval-config.nix" {
      system = "x86_64-linux";
      specialArgs.confLib.findMetaConfig = _: {
        addresses.primary.address = address;
      };
      modules = [
        ({ lib, ... }: {
          options.cluster = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          config = {
            system.stateVersion = "26.05";
            networking.hostName = "blog-fixture";
          };
        })
      ]
      ++ modules;
    }).config;
  evaluate = evaluateAt "127.0.0.1";
  disabled = evaluate [ composition ];
  enabled = evaluate [
    composition
    { services.vpsfree-static-blog.enable = true; }
  ];
  invalidProxy = evaluateAt "::1" [ composition ];
  broadHTTP = evaluate [
    composition
    { networking.firewall.allowedTCPPorts = [ 80 ]; }
  ];
  broadPrivate = evaluate [
    composition
    {
      networking.firewall.interfaces.eth0.allowedTCPPortRanges = [
        {
          from = 8080;
          to = 8091;
        }
      ];
    }
  ];
  published = evaluate [
    composition
    {
      services.vpsfree-static-blog = {
        enable = true;
        publication = {
          enable = true;
          secretFile = "/run/secrets/blog-deployment";
        };
      };
    }
  ];
  missingPolicy = evaluate [
    composition
    {
      services.vpsfree-static-blog = {
        enable = true;
        publication.enable = true;
      };
    }
  ];
  identities = c: {
    users = lib.genAttrs [ "wordpress" "nginx" "mysql" ] (
      name:
      let
        user = c.users.users.${name};
      in
      {
        inherit (user)
          uid
          group
          isSystemUser
          home
          createHome
          ;
      }
    );
    groups = {
      nginx = c.users.groups.nginx.gid;
      mysql = c.users.groups.mysql.gid;
    };
  };
  noWordpressRuntime =
    c:
    c.services.wordpress.sites == { }
    && !c.services.mysql.enable
    && c.services.phpfpm.pools == { }
    && lib.all (unit: !(builtins.hasAttr unit c.systemd.services)) [
      "mysql"
      "phpfpm-wordpress-blog.vpsfree.cz"
      "wordpress-init-blog.vpsfree.cz"
      "wordpress-cron-blog.vpsfree.cz"
    ]
    && !(c.systemd.timers ? "wordpress-cron-blog.vpsfree.cz")
    && !lib.any (
      package:
      lib.elem (lib.getName package) [
        "wp-blog"
        "wp-blog-core-update-db"
      ]
    ) c.environment.systemPackages
    && lib.all (host: lib.all (entry: entry.port != 8081) host.listen) (
      lib.attrValues c.services.nginx.virtualHosts
    )
    && !lib.any (
      rule: lib.hasInfix "/var/lib/mysql" rule || lib.hasInfix "/var/lib/wordpress" rule
    ) c.systemd.tmpfiles.rules
    && !lib.hasInfix "/var/lib/mysql" c.system.activationScripts.script
    && !lib.hasInfix "/var/lib/wordpress" c.system.activationScripts.script;
  generated =
    c:
    builtins.stringLength c.systemd.units."nginx.service".text > 0
    && builtins.stringLength c.system.activationScripts.script > 0;
  broadlyAllowed =
    c: port:
    let
      permits =
        firewall:
        lib.elem port firewall.allowedTCPPorts
        || lib.any (range: range.from <= port && port <= range.to) firewall.allowedTCPPortRanges;
    in
    permits c.networking.firewall || lib.any permits (lib.attrValues c.networking.firewall.interfaces);
  cs = enabled.services.nginx.virtualHosts.static-blog-cs;
  en = enabled.services.nginx.virtualHosts.static-blog-en;
  generatedNginx = enabled.environment.etc."nginx/nginx.conf".source.text;
  cluster = (import (site + /module.nix) { }).cluster."cz.vpsfree/containers/int.blog";
in
assert lib.all noWordpressRuntime [
  disabled
  enabled
  published
];
assert generated disabled && generated enabled;
assert identities disabled == identities enabled && identities enabled == identities published;
assert disabled.users.users.wordpress.uid == null;
assert
  disabled.users.users.wordpress.group == "nginx" && disabled.users.users.wordpress.isSystemUser;
assert disabled.users.users.nginx.uid == 60 && disabled.users.groups.nginx.gid == 60;
assert disabled.users.users.mysql.uid == 84 && disabled.users.groups.mysql.gid == 84;
assert disabled.users.users.mysql.group == "mysql";
assert disabled.users.users.mysql.description == "MySQL server user";
assert !disabled.users.users.mysql.isSystemUser;
assert lib.all
  (
    name:
    let
      user = disabled.users.users.${name};
    in
    user.home == "/var/empty"
    && !user.createHome
    && !user.isNormalUser
    && user.shell == disabled.users.users.nginx.shell
  )
  [
    "wordpress"
    "mysql"
  ];
assert !(disabled.services.nginx.virtualHosts ? static-blog-cs);
assert !(disabled.systemd.services ? blog-static-pull);
assert !(disabled.systemd.services ? blog-upload);
assert !(disabled.systemd.services ? blog-release-prune);
assert !(enabled.systemd.services ? blog-release-prune);
assert !(disabled.systemd.timers ? blog-release-prune);
assert lib.all
  (
    c:
    c.networking.firewall.enable
    && lib.all (port: !(broadlyAllowed c port)) [
      80
      8080
      8081
      8091
      3306
    ]
  )
  [
    disabled
    enabled
  ];
assert enabled.networking.firewall.backend == "iptables" && !enabled.networking.nftables.enable;
assert enabled.services.nginx.enableReload && disabled.services.nginx.enableReload;
assert enabled.networking.firewall.extraCommands == disabled.networking.firewall.extraCommands;
assert lib.hasInfix "-s 127.0.0.1/32 --dport 80" enabled.networking.firewall.extraCommands;
assert !(lib.hasInfix "--dport 8080" enabled.networking.firewall.extraCommands);
assert !(lib.hasInfix "vpsf-blog-smtp" enabled.networking.firewall.extraCommands);
assert !(lib.hasInfix "--uid-owner" enabled.networking.firewall.extraCommands);
assert
  enabled.networking.firewall.extraStopCommands == ''
    while iptables -w -D OUTPUT -j vpsf-blog-smtp4 2>/dev/null; do :; done
    iptables -w -F vpsf-blog-smtp4 2>/dev/null || true
    iptables -w -X vpsf-blog-smtp4 2>/dev/null || true
    while ip6tables -w -D OUTPUT -j vpsf-blog-smtp6 2>/dev/null; do :; done
    ip6tables -w -F vpsf-blog-smtp6 2>/dev/null || true
    ip6tables -w -X vpsf-blog-smtp6 2>/dev/null || true
  '';
assert lib.any (a: !a.assertion && lib.hasInfix "IPv4 primary" a.message) invalidProxy.assertions;
assert lib.any (a: !a.assertion && lib.hasInfix "TCP/80" a.message) broadHTTP.assertions;
assert lib.any (
  a: !a.assertion && lib.hasInfix "Private and retired" a.message
) broadPrivate.assertions;
assert lib.all (name: disabled.services.nginx.virtualHosts.${name}.locations."/".return == "503") [
  "blog-front-cs"
  "blog-front-en"
];
assert lib.all
  (
    name: enabled.services.nginx.virtualHosts.${name}.locations."/".proxyPass == "http://127.0.0.1:8080"
  )
  [
    "blog-front-cs"
    "blog-front-en"
  ];
assert lib.all
  (
    c:
    lib.all (name: c.services.nginx.virtualHosts.${name}.locations."/".return == "444") [
      "blog-front-unknown-host"
    ]
    &&
      lib.all
        (
          name:
          c.services.nginx.virtualHosts.${name}.locations."= /_deploy/blog".return == "404"
          && c.services.nginx.virtualHosts.${name}.locations."^~ /_deploy/".return == "404"
          && c.services.nginx.virtualHosts.${name}.locations."^~ /_hooks/".return == "404"
        )
        [
          "blog-front-cs"
          "blog-front-en"
        ]
  )
  [
    disabled
    enabled
  ];
assert lib.all (host: lib.all (entry: entry.addr == "127.0.0.1" && entry.port == 8080) host.listen)
  [
    cs
    en
  ];
assert lib.all
  (
    name:
    lib.hasInfix "set_real_ip_from 127.0.0.1/32;"
      disabled.services.nginx.virtualHosts.${name}.extraConfig
  )
  [
    "blog-front-cs"
    "blog-front-en"
  ];
assert lib.all
  (
    pair:
    let
      location = enabled.services.nginx.virtualHosts.${pair.name}.locations."/";
    in
    !location.recommendedProxySettings
    && lib.hasInfix "proxy_set_header Host ${pair.host};" location.extraConfig
    && lib.hasInfix "proxy_set_header X-Real-IP $remote_addr;" location.extraConfig
    && lib.hasInfix "proxy_set_header X-Forwarded-Proto https;" location.extraConfig
  )
  [
    {
      name = "blog-front-cs";
      host = "blog.vpsfree.cz";
    }
    {
      name = "blog-front-en";
      host = "blog.vpsfree.org";
    }
  ];
assert cs.root == "/var/lib/blog/current/cs" && en.root == "/var/lib/blog/current/en";
assert lib.all
  (
    host:
    let
      feed = host.locations."= /feed/";
    in
    feed.alias == null
    && feed.tryFiles == "/feed/index.xml =404"
    && lib.hasInfix "types { }" feed.extraConfig
    && lib.hasInfix "default_type application/rss+xml;" feed.extraConfig
  )
  [
    cs
    en
  ];
assert
  lib.count (line: lib.hasInfix "try_files /feed/index.xml =404;" line) (
    lib.splitString "\n" generatedNginx
  ) == 2;
assert !(lib.hasInfix "alias /var/lib/blog/current/" generatedNginx);
assert lib.all (vhost: lib.hasInfix "absolute_redirect off;" vhost.extraConfig) [
  cs
  en
];
assert
  lib.count (line: lib.hasInfix "absolute_redirect off;" line) (lib.splitString "\n" generatedNginx)
  == 2;

assert cs.locations."~* \\.php(?:/|$)".return == "404";
assert enabled.services.nginx.virtualHosts.static-blog-unknown-host.default;
assert enabled.services.nginx.virtualHosts.static-blog-unknown-host.locations."/".return == "444";
assert !(enabled.systemd.services ? blog-static-pull);
assert !(enabled.systemd.timers ? blog-static-pull);
assert published.services.vpsfree-static-blog.publication.enable;
assert lib.any (
  a: !a.assertion && lib.hasInfix "external runtime deployment key" a.message
) missingPolicy.assertions;
assert builtins.hasAttr "blog-publication-maintenance" disabled.system.preSwitchChecks;
assert lib.hasInfix "check-maintenance"
  disabled.system.preSwitchChecks.blog-publication-maintenance;
assert lib.hasInfix "check-maintenance"
  published.system.preSwitchChecks.blog-publication-maintenance;
assert
  builtins.fromJSON (builtins.readFile published.environment.etc."blog-release-policy.json".source)
  == {
    schema = 2;
    authority = "hmac-upload-v1";
    implementation_sha256 = builtins.hashString "sha256" (
      builtins.readFile ../tools/blog-static-release.py + builtins.readFile ../tools/blog-upload.py
    );
    repository = "vpsfreecz/blog";
    workflow_path = ".github/workflows/build.yml";
    enabled = true;
    state_dir = "/var/lib/blog";
    keep_releases = 5;
  };
assert published.services.vpsfree-static-blog.retention.keepReleases == 5;
assert
  !(builtins.tryEval
    (evaluate [
      composition
      { services.vpsfree-static-blog.retention.keepReleases = 0; }
    ]).services.vpsfree-static-blog.retention.keepReleases
  ).success;
assert published.systemd.services.blog-release-prune.serviceConfig.User == "blog-release";
assert published.systemd.services.blog-release-prune.serviceConfig.Group == "blog-release";
assert published.systemd.services.blog-release-prune.serviceConfig.PrivateNetwork;
assert published.systemd.services.blog-release-prune.serviceConfig.NoNewPrivileges;
assert published.systemd.services.blog-release-prune.serviceConfig.ProtectSystem == "strict";
assert lib.hasSuffix "bin/blog-static-release prune"
  published.systemd.services.blog-release-prune.serviceConfig.ExecStart;
assert published.systemd.timers.blog-release-prune.timerConfig.OnCalendar == "daily";
assert published.systemd.timers.blog-release-prune.timerConfig.Persistent;
assert published.systemd.timers.blog-release-prune.wantedBy == [ "timers.target" ];
assert lib.all (rule: lib.elem rule published.systemd.tmpfiles.rules) [
  "d /var/lib/blog-control 0750 root blog-release -"
  "f /var/lib/blog-control/transaction.lock 0660 root blog-release -"
];
assert !(published.systemd.timers ? blog-static-pull);

assert builtins.attrNames cluster.healthChecks.systemd.unitProperties == [ "nginx.service" ];
assert builtins.length cluster.healthChecks.machineCommands == 2;
assert lib.all
  (
    host:
    lib.any (
      check: lib.elem "Host: ${host}" check.command && lib.elem "http://localhost/" check.command
    ) cluster.healthChecks.machineCommands
  )
  [
    "blog.vpsfree.cz"
    "blog.vpsfree.org"
  ];
assert cluster.container.id == 29942 && cluster.host.target == "172.16.8.4";
{
  noWordpressRuntimeOrDataActivation = true;
  backendEnabledAndUnavailableModes = true;
  nginxConfigurationGenerated = generated disabled && generated enabled;
  retainedIdentities = identities disabled;
  bothFrontendHealthChecks = true;
  exactProxyFirewallAndOldSMTPTeardown = true;
  obsoletePullRemoved = true;
  operatorPolicyAndMaintenanceGate = true;
  newListenerPorts = map (listen: listen.port) cs.listen;
  staticRoots = [
    cs.root
    en.root
  ];
  feedContentType = cs.locations."= /feed/".extraConfig;
  feedInternalMappings = map (host: host.locations."= /feed/".tryFiles) [
    cs
    en
  ];
  feedMappingsInGeneratedConfig = true;
  internalDirectoryRedirectsRelative = true;
  phpDenied = true;
  unknownHostRejected = true;
}
