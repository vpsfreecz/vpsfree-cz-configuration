{ nixpkgs }:
let
  lib = nixpkgs.lib;
  meta = _: {
    addresses.primary.address = "192.0.2.44";
    services = lib.genAttrs [ "alertmanager" "prometheus" "grafana" "geminabox" "bepasty" ] (_: {
      address = "192.0.2.44";
      port = 1234;
    });
  };
  evaluate =
    modules: settings:
    (import "${nixpkgs}/nixos/lib/eval-config.nix" {
      system = "x86_64-linux";
      specialArgs.confLib.findMetaConfig = meta;
      modules = modules ++ [
        ({ lib, ... }: {
          options.cluster = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          config = {
            services.nginx.enable = true;
            services.nginx.recommendedProxySettings = true;
            security.acme = {
              acceptTerms = true;
              defaults.email = "fixture@example.invalid";
            };
            system.stateVersion = lib.mkDefault "26.05";
          };
        })
        settings
      ];
    }).config;
  blog = ../cluster/cz.vpsfree/containers/prg/proxy/blog.nix;
  proxyComposition =
    withBlog:
    {
      config,
      pkgs,
      confLib,
      ...
    }:
    (import ../cluster/cz.vpsfree/containers/prg/proxy/config.nix { inherit config pkgs confLib; })
    // {
      imports = lib.optional withBlog blog;
    };
  configured = evaluate [ blog ] { };
  full = evaluate [ (proxyComposition true) ] { };
  withoutBlog = evaluate [ (proxyComposition false) ] { };
  vhosts = c: c.services.nginx.virtualHosts;
  unrelated =
    c:
    lib.mapAttrs
      (_: v: {
        inherit (v)
          serverName
          serverAliases
          listen
          locations
          extraConfig
          root
          forceSSL
          enableACME
          ;
      })
      (
        builtins.removeAttrs (vhosts c) [
          "blog.vpsfree.cz"
          "blog.vpsfree.org"
        ]
      );
  generated =
    c:
    builtins.stringLength c.systemd.units."nginx.service".text > 0
    && builtins.stringLength c.system.activationScripts.script > 0;
  fixed =
    c: host:
    let
      v = (vhosts c).${host};
      location = v.locations."/";
    in
    v.enableACME
    && v.forceSSL
    && builtins.attrNames v.locations == [ "/" ]
    && location.proxyPass == "http://192.0.2.44:80"
    && !location.recommendedProxySettings
    && lib.hasInfix "proxy_set_header Host ${host};" location.extraConfig
    && lib.hasInfix "proxy_set_header X-Real-IP $remote_addr;" location.extraConfig
    && lib.hasInfix "proxy_set_header X-Forwarded-Proto $scheme;" location.extraConfig
    && !(lib.hasInfix "X-Forwarded-For" location.extraConfig);
in
assert fixed configured "blog.vpsfree.cz" && fixed configured "blog.vpsfree.org";
assert configured.security.acme.certs ? "blog.vpsfree.cz";
assert configured.security.acme.certs ? "blog.vpsfree.org";
assert unrelated full == unrelated withoutBlog;
assert full.services.nginx.enableReload;
assert full.systemd.units."nginx.service".text == withoutBlog.systemd.units."nginx.service".text;
assert generated configured && generated full;
{
  fixedBackend80BothHosts = true;
  bothLanguageTLSUnconditional = true;
  noSpecialProxyHookOrMode = true;
  unrelatedProxyVhostsAndMainUnitPreserved = true;
  nginxGenerated = true;
}
