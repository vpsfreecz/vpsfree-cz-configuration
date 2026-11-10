{ nixpkgs }:
let
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  inherit (pkgs) lib;
  host = "images.aitherdev.int.vpsfree.cz";
  evaluate =
    enabled:
    import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = "x86_64-linux";
      modules = [
        ../../cluster/cz.vpsfree/machines/aitherdev/osctl-repo-dev.nix
        ({ lib, ... }: {
          options.services.dev-workspaces = lib.mkOption { type = lib.types.attrs; };
          config = {
            # This fixture evaluates a service, not a bootable machine.
            boot.isContainer = true;
            system.stateVersion = "26.05";
            services.dev-workspaces = {
              enable = true;
              tls.caStateDirectory = "/var/lib/dev-workspaces/pki";
              lockFile = "/run/lock/dev-workspace-substrate.lock";
              listenAddress = "172.16.106.40";
            };
            services.osctl-repo-dev.enable = enabled;
            services.nginx = {
              enable = true;
              recommendedProxySettings = true;
            };
          };
        })
      ];
    };
  enabled = (evaluate true).config;
  disabled = (evaluate false).config;
  vhost = enabled.services.nginx.virtualHosts.${host};
  location = vhost.locations."/";
in
assert lib.assertMsg (lib.all (a: a.assertion) enabled.assertions) (
  lib.concatMapStringsSep "\n" (a: a.message) (builtins.filter (a: !a.assertion) enabled.assertions)
);
assert vhost.forceSSL;
assert location.proxyPass == "http://127.0.0.1:19485";
assert !location.recommendedProxySettings;
assert builtins.attrNames vhost.locations == [ "/" ];
assert vhost.sslCertificate == "/var/lib/osctl-repo-dev/tls/current/server.pem";
assert vhost.sslCertificateKey == "/var/lib/osctl-repo-dev/tls/current/server-key.pem";
assert lib.hasInfix "proxy_set_header X-Repo-Client-IP $remote_addr;" location.extraConfig;
assert lib.hasInfix ''proxy_set_header Connection "";'' location.extraConfig;
assert !(lib.hasInfix "$proxy_add_x_forwarded_for" location.extraConfig);
assert lib.hasInfix "proxy_buffering off;" location.extraConfig;
assert lib.hasInfix "proxy_request_buffering off;" location.extraConfig;
assert lib.hasInfix "proxy_cache off;" location.extraConfig;
assert builtins.elem "osctl-repo-dev-certificate.service" enabled.systemd.services.nginx.requires;
assert enabled.systemd.services.osctl-repo-dev-certificate.serviceConfig.TimeoutStartSec == "2min";
assert enabled.systemd.timers.osctl-repo-dev-certificate-renewal.timerConfig.OnCalendar == "daily";
assert enabled.systemd.timers.osctl-repo-dev-certificate-renewal.timerConfig.Persistent;
assert !(builtins.hasAttr host disabled.services.nginx.virtualHosts);
assert !(builtins.hasAttr "osctl-repo-dev-certificate" disabled.systemd.services);
assert enabled.networking.firewall.allowedTCPPorts == disabled.networking.firewall.allowedTCPPorts;
{
  upstream = location.proxyPass;
  requesterHeader = "X-Repo-Client-IP";
  certificate = vhost.sslCertificate;
  certificateKey = vhost.sslCertificateKey;
  listen = vhost.listen;
  renewal = enabled.systemd.timers.osctl-repo-dev-certificate-renewal.timerConfig;
  nginxRequires = enabled.systemd.services.nginx.requires;
  certificateScript = enabled.systemd.services.osctl-repo-dev-certificate.script;
}
