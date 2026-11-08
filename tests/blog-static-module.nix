{ nixpkgs }:
let
  lib = nixpkgs.lib;
  site = ../cluster/cz.vpsfree/containers/int.blog;
  wordpress = site + /wordpress.nix;
  # Exercise the site's actual imports/settings without unrelated base profiles.
  composition =
    { config, ... }:
    let
      module = import (site + /config.nix) { inherit config; };
    in
    module
    // {
      imports = builtins.filter (
        path:
        !(lib.elem path [
          ../environments/base.nix
          ../profiles/ct.nix
        ])
      ) module.imports;
    };
  evaluate =
    modules:
    (import "${nixpkgs}/nixos/lib/eval-config.nix" {
      system = "x86_64-linux";
      specialArgs.confLib.findMetaConfig = _: {
        addresses.primary.address = "127.0.0.1";
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
  original = evaluate [ wordpress ];
  disabled = evaluate [ composition ];
  enabled = evaluate [
    composition
    {
      services.vpsfree-static-blog.enable = true;
      services.nginx.enableReload = true;
    }
  ];
  selected = evaluate [
    composition
    {
      services.vpsfree-static-blog = {
        enable = true;
        serveStatic = true;
      };
    }
  ];
  invalidRoute = evaluate [
    composition
    { services.vpsfree-static-blog.serveStatic = true; }
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
  wordpressState = c: {
    settings = c.services.wordpress.sites."blog.vpsfree.cz".settings;
    root = c.services.nginx.virtualHosts."blog.vpsfree.cz".root;
    listen = c.services.nginx.virtualHosts."blog.vpsfree.cz".listen;
    phpPools = builtins.attrNames c.services.phpfpm.pools;
    mysql = c.services.mysql.enable;
    inherit (c.services.mysql) dataDir;
    uploadsDir = c.services.wordpress.sites."blog.vpsfree.cz".uploadsDir;
    fontsDir = c.services.wordpress.sites."blog.vpsfree.cz".fontsDir;
    identities = identities c;
  };
  effective = c: {
    wordpress = wordpressState c;
    nginx = c.services.nginx.enable;
    virtualHostNames = builtins.attrNames c.services.nginx.virtualHosts;
    tcpPorts = c.networking.firewall.allowedTCPPorts;
    firewall = c.networking.firewall.extraCommands;
    units = builtins.attrNames c.systemd.services;
    timers = builtins.attrNames c.systemd.timers;
    users = builtins.attrNames c.users.users;
    tmpfiles = c.systemd.tmpfiles.rules;
  };
  activeWordpress =
    c:
    c.services.nginx.enable
    && c.services.mysql.enable
    && c.services.phpfpm.pools ? "wordpress-blog.vpsfree.cz"
    && lib.all (unit: builtins.hasAttr unit c.systemd.services) [
      "nginx"
      "mysql"
      "phpfpm-wordpress-blog.vpsfree.cz"
      "wordpress-init-blog.vpsfree.cz"
      "wordpress-cron-blog.vpsfree.cz"
    ]
    && c.systemd.timers ? "wordpress-cron-blog.vpsfree.cz"
    && lib.all (name: lib.any (package: lib.getName package == name) c.environment.systemPackages) [
      "wp-blog"
      "wp-blog-core-update-db"
    ];
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
  disabledSame = wordpressState original == wordpressState disabled;
  wpPreserved = wordpressState original == wordpressState enabled;
  cluster = (import (site + /module.nix) { }).cluster."cz.vpsfree/containers/int.blog";
in
assert disabledSame && wpPreserved;
assert activeWordpress disabled && activeWordpress enabled;
assert generated disabled && generated enabled;
assert identities disabled == identities original && identities enabled == identities original;
assert disabled.users.users.wordpress.uid == null;
assert disabled.users.users.nginx.uid == 60 && disabled.users.groups.nginx.gid == 60;
assert disabled.users.users.mysql.uid == 84 && disabled.users.groups.mysql.gid == 84;
assert !disabled.users.users.mysql.isSystemUser;
assert disabled.services.mysql.dataDir == "/var/lib/mysql";
assert
  disabled.services.wordpress.sites."blog.vpsfree.cz".uploadsDir
  == "/var/lib/wordpress/blog.vpsfree.cz/uploads";
assert
  disabled.services.wordpress.sites."blog.vpsfree.cz".fontsDir
  == "/var/lib/wordpress/blog.vpsfree.cz/uploads/fonts";
assert
  map (listen: listen.port) disabled.services.nginx.virtualHosts."blog.vpsfree.cz".listen == [ 8081 ];
assert !(disabled.services.nginx.virtualHosts ? static-blog-cs);
assert !(disabled.systemd.services ? blog-static-pull);
assert !(disabled.systemd.services ? blog-upload);
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
assert lib.hasInfix original.networking.firewall.extraCommands
  enabled.networking.firewall.extraCommands;
assert enabled.networking.firewall.extraCommands == disabled.networking.firewall.extraCommands;
assert !(lib.hasInfix "--dport 8080" enabled.networking.firewall.extraCommands);
assert lib.any (
  a: !a.assertion && lib.hasInfix "routing requires" a.message
) invalidRoute.assertions;
assert !disabled.services.vpsfree-static-blog.serveStatic;
assert
  disabled.services.nginx.virtualHosts.blog-front-cs.locations."/".proxyPass
  == "http://127.0.0.1:8081";
assert disabled.services.nginx.virtualHosts.blog-front-en.locations."/".return == "503";
assert lib.all
  (
    name:
    selected.services.nginx.virtualHosts.${name}.locations."/".proxyPass == "http://127.0.0.1:8080"
  )
  [
    "blog-front-cs"
    "blog-front-en"
  ];
assert generated selected;
assert lib.all
  (
    c:
    lib.all (name: c.services.nginx.virtualHosts.${name}.locations."/".return == "444") [
      "blog-front-unknown-host"
      "blog-wordpress-unknown-host"
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
    selected
  ];
assert lib.all (host: lib.all (entry: entry.addr == "127.0.0.1" && entry.port == 8080) host.listen)
  [
    cs
    en
  ];
assert lib.all (
  entry: entry.addr == "127.0.0.1" && entry.port == 8081
) disabled.services.nginx.virtualHosts."blog.vpsfree.cz".listen;
assert lib.hasInfix "set_real_ip_from 127.0.0.1/32;"
  disabled.services.nginx.virtualHosts."blog.vpsfree.cz".extraConfig;
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
      location = selected.services.nginx.virtualHosts.${pair.name}.locations."/";
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
  enabled.services.nginx.virtualHosts."blog.vpsfree.cz"
];
assert
  lib.count (line: lib.hasInfix "absolute_redirect off;" line) (lib.splitString "\n" generatedNginx)
  == 3;

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
  };
assert lib.all (rule: lib.elem rule published.systemd.tmpfiles.rules) [
  "d /var/lib/blog-control 0750 root blog-release -"
  "f /var/lib/blog-control/transaction.lock 0660 root blog-release -"
];
assert !(published.systemd.timers ? blog-static-pull);

assert lib.all (unit: builtins.hasAttr unit cluster.healthChecks.systemd.unitProperties) [
  "nginx.service"
  "mysql.service"
  "phpfpm-wordpress-blog.vpsfree.cz.service"
  "wordpress-init-blog.vpsfree.cz.service"
];
assert lib.any (
  check: lib.elem "http://localhost/" check.command
) cluster.healthChecks.machineCommands;
assert lib.any (
  check: lib.elem "http://127.0.0.1:8081/" check.command
) cluster.healthChecks.machineCommands;
assert cluster.container.id == 29942 && cluster.host.target == "172.16.8.4";
{
  disabledWordpressStatePreserved = disabledSame;
  backendSelectedModesAndInternalPorts = true;
  existingWordpressPreserved = wpPreserved;
  activeWordpressBothStates = activeWordpress disabled && activeWordpress enabled;
  nginxConfigurationGenerated = generated disabled && generated enabled;
  retainedIdentities = identities disabled;
  wordpressHealthChecksPreserved = true;
  obsoletePullRemoved = true;
  operatorPolicyAndMaintenanceGate = true;
  wordpressListenerPorts = map (
    listen: listen.port
  ) enabled.services.nginx.virtualHosts."blog.vpsfree.cz".listen;
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
