{ nixpkgs }:
let
  lib = nixpkgs.lib;
  site = ../cluster/cz.vpsfree/containers/int.blog;
  evaluate =
    enabled:
    (import "${nixpkgs}/nixos/lib/eval-config.nix" {
      system = "x86_64-linux";
      specialArgs.confLib.findMetaConfig = _: { addresses.primary.address = "192.0.2.44"; };
      modules = [
        (site + /blog-routing.nix)
        (site + /blog-upload.nix)
        (site + /static-blog.nix)
        (site + /legacy-routes.nix)
        ({ lib, ... }: {
          options.cluster = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          config = {
            system.stateVersion = "26.05";
            services.vpsfree-static-blog.enable = enabled;
          };
        })
      ];
    }).config;
  disabled = evaluate false;
  enabled = evaluate true;
  cs = enabled.services.nginx.virtualHosts.static-blog-cs;
  en = enabled.services.nginx.virtualHosts.static-blog-en;
  generated =
    c:
    builtins.stringLength c.systemd.units."nginx.service".text > 0
    && builtins.stringLength c.system.activationScripts.script > 0;
  projection = builtins.fromJSON (builtins.readFile ../data/blog-legacy-routes.json);
in
assert !(lib.hasInfix "$blog_legacy_redirect" disabled.services.nginx.appendHttpConfig);
assert lib.hasInfix "map $request_uri $blog_legacy_redirect"
  enabled.services.nginx.appendHttpConfig;
assert lib.hasInfix "map $args $blog_legacy_identity_query" enabled.services.nginx.appendHttpConfig;
assert lib.hasInfix "return 301 $blog_legacy_redirect;" cs.extraConfig;
assert lib.hasInfix "return 404;" cs.extraConfig;
assert !(lib.hasInfix "$blog_legacy" en.extraConfig);
assert cs.locations."= /feed/".alias == null;
assert cs.locations."= /feed/".tryFiles == "/feed/index.xml =404";
assert lib.all (host: lib.all (entry: entry.addr == "127.0.0.1" && entry.port == 8080) host.listen)
  [
    cs
    en
  ];
assert cs.locations."~* \\.php(?:/|$)".return == "404";
assert lib.all
  (
    c:
    c.services.wordpress.sites == { }
    && !c.services.mysql.enable
    && c.services.phpfpm.pools == { }
    && !(c.systemd.services ? "wordpress-cron-blog.vpsfree.cz")
  )
  [
    disabled
    enabled
  ];
assert disabled.services.nginx.virtualHosts.blog-front-cs.locations."/".return == "503";
assert
  enabled.services.nginx.virtualHosts.blog-front-cs.locations."/".proxyPass
  == "http://127.0.0.1:8080";
assert generated disabled && generated enabled;
assert builtins.length projection.aliases == 540;
{
  disabledHasNoLegacyMaps = true;
  nginxGenerated = true;
  retiredRuntimeAbsent = true;
  feedAndPHPProtectionRetained = true;
  englishHasNoCzechAliases = true;
  projection = projection;
  maps = enabled.services.nginx.appendHttpConfig;
  redirectRules = cs.extraConfig;
}
