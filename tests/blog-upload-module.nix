{ nixpkgs }:
let
  lib = nixpkgs.lib;
  site = ../cluster/cz.vpsfree/containers/int.blog;
  composition =
    { config, ... }:
    let
      base = import (site + /config.nix) { inherit config; };
    in
    base
    // {
      # Exercise reusable module defaults/modes; machine opt-in is checked separately.
      services = builtins.removeAttrs (base.services or { }) [ "vpsfree-static-blog" ];
      imports = builtins.filter (
        path:
        !(lib.elem path [
          ../environments/base.nix
          ../profiles/ct.nix
        ])
      ) base.imports;
    };
  evaluate =
    settings:
    (import "${nixpkgs}/nixos/lib/eval-config.nix" {
      system = "x86_64-linux";
      specialArgs.confLib.findMetaConfig = _: { addresses.primary.address = "192.0.2.44"; };
      modules = [
        composition
        ({ lib, ... }: {
          options.cluster = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          config.system.stateVersion = lib.mkDefault "26.05";
        })
        settings
      ];
    }).config;
  disabled = evaluate { };
  enabled = evaluate {
    services.vpsfree-static-blog = {
      enable = true;
      publication = {
        enable = true;
        secretFile = "/run/secrets/blog-deployment";
      };
    };
  };
  storageOnly = evaluate { services.vpsfree-static-blog.enable = true; };
  missing = evaluate {
    services.vpsfree-static-blog = {
      enable = true;
      publication.enable = true;
    };
  };
  storeSecret = evaluate {
    services.vpsfree-static-blog = {
      enable = true;
      publication = {
        enable = true;
        secretFile = "/nix/store/secret";
      };
    };
  };
  rejects =
    c:
    lib.any (a: !a.assertion && lib.hasInfix "external runtime deployment key" a.message) c.assertions;
  service = enabled.systemd.services.blog-upload.serviceConfig;
  route = c: c.services.nginx.virtualHosts.blog-front-cs.locations."= /_deploy/blog";
  generated =
    c:
    builtins.stringLength c.systemd.units."nginx.service".text > 0
    && builtins.stringLength c.system.activationScripts.script > 0;
  retiredRuntimeAbsent =
    c:
    c.services.wordpress.sites == { }
    && !c.services.mysql.enable
    && c.services.phpfpm.pools == { }
    && !(c.systemd.services ? "wordpress-cron-blog.vpsfree.cz")
    && !(c.systemd.services ? mysql);
  identities =
    c:
    lib.genAttrs [ "wordpress" "mysql" "nginx" ] (name: {
      inherit (c.users.users.${name})
        uid
        group
        home
        createHome
        isSystemUser
        ;
    });

in
assert !(disabled.systemd.services ? blog-upload);
assert !(disabled.systemd.services ? blog-release-prune);
assert enabled.systemd.services.blog-release-prune.serviceConfig.User == "blog-release";
assert !(enabled.systemd.services.blog-release-prune.serviceConfig ? LoadCredential);
assert !(lib.elem "blog-release-prune.service" enabled.systemd.services.blog-upload.after);
assert enabled.systemd.timers.blog-release-prune.timerConfig.OnCalendar == "daily";
assert
  disabled.services.nginx.virtualHosts.blog-front-cs.locations."= /_deploy/blog".return == "404";
assert rejects missing && rejects storeSecret;
assert generated disabled && generated enabled && generated storageOnly;
assert lib.all retiredRuntimeAbsent [
  disabled
  storageOnly
  enabled
];
assert identities enabled == identities disabled && identities storageOnly == identities disabled;
assert !(storageOnly.systemd.services ? blog-upload);
assert (route storageOnly).return == "404";
assert enabled.networking.firewall.extraCommands == disabled.networking.firewall.extraCommands;
assert enabled.networking.firewall.allowedTCPPorts == disabled.networking.firewall.allowedTCPPorts;
assert service.User == "blog-release" && service.Group == "blog-release";
assert service.LoadCredential == [ "deployment-key:/run/secrets/blog-deployment" ];
assert
  service.ReadWritePaths == [
    "/var/lib/blog"
    "/var/lib/blog-control/transaction.lock"
  ];
assert service.NoNewPrivileges && service.ProtectSystem == "strict" && service.ProtectHome;
assert lib.hasInfix "--secret-file %d/deployment-key" service.ExecStart;
assert
  !(enabled.systemd.services ? blog-webhook) && !(enabled.systemd.services ? blog-webhook-work);
assert
  !(enabled.systemd.services ? blog-static-pull) && !(enabled.systemd.paths ? blog-webhook-work);
assert !(enabled.users.users ? blog-webhook);
assert lib.all
  (
    c:
    (route c).proxyPass == "http://127.0.0.1:8091"
    && lib.all (directive: lib.hasInfix directive (route c).extraConfig) [
      "client_max_body_size 512m;"
      "client_body_timeout 180s;"
      "proxy_read_timeout 180s;"
      "proxy_send_timeout 180s;"
      "proxy_pass_request_body on;"
      "access_log off;"
      "error_log /dev/null;"
    ]
    && c.services.nginx.virtualHosts.blog-front-en.locations."= /_deploy/blog".return == "404"
    &&
      lib.all
        (
          name:
          c.services.nginx.virtualHosts.${name}.locations."^~ /_hooks/".return == "404"
          && c.services.nginx.virtualHosts.${name}.locations."^~ /_deploy/".return == "404"
        )
        [
          "blog-front-cs"
          "blog-front-en"
        ]
  )
  [
    enabled
  ];
{
  defaultOffAndRuntimeKey = true;
  oneSynchronousNonrootService = true;
  obsoleteWorkerQueuePullRemoved = true;
  exactCzechUploadWhenAuthorized = true;
  retiredRuntimeAbsentAndIdentitiesRetained = true;
  generatedConfiguration = true;
}
