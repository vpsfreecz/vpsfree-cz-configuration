{ pkgs, machines }:
let
  inherit (pkgs) lib;
  production = import ../cluster/cz.vpsfree/containers/prg/proxy/config.nix {
    inherit pkgs lib;
    config.cluster = lib.mapAttrs (_: machine: machine.metaConfig) machines;
    confLib.findMetaConfig = { cluster, name }: cluster.${name};
  };
  hosts = [
    "mon1.prg.vpsfree.cz"
    "mon2.prg.vpsfree.cz"
  ];
  fixture = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      {
        services.nginx = {
          enable = true;
          enableReload = true;
          validateConfigFile = false;
          logError = "stderr";
          inherit (production.services.nginx) commonHttpConfig recommendedProxySettings;
          virtualHosts = lib.listToAttrs (
            lib.imap0 (
              index: name:
              let
                source = production.services.nginx.virtualHosts.${name};
              in
              lib.nameValuePair name {
                inherit (source) basicAuthFile;
                listen = [
                  {
                    addr = "127.0.0.1";
                    port = 18080;
                  }
                ];
                http2 = true;
                # NixOS emits vhost.http2 only for TLS listeners. This local
                # fixture uses prior-knowledge h2c instead of public TLS.
                extraConfig = "http2 on;";
                locations = lib.mapAttrs (
                  _: location:
                  location
                  // lib.optionalAttrs (location ? proxyPass) {
                    proxyPass = "http://127.0.0.1:${toString (18090 + index)}";
                  }
                ) source.locations;
              }
            ) hosts
          );
        };
        system.stateVersion = "26.05";
      }
    ];
  };
  configFile = fixture.config.environment.etc."nginx/nginx.conf".source;
  python = pkgs.python3.withPackages (ps: [ ps.h2 ]);
  inputs = [
    python
    pkgs.nginx
    pkgs.apacheHttpd
  ];
  integration =
    pkgs.runCommand "prometheus-query-access-integration"
      {
        nativeBuildInputs = inputs;
      }
      ''
        python3 ${./prometheus-query-access.py} ${configFile}
        touch "$out"
      '';
in
assert
  production.networking.firewall.allowedTCPPorts == [
    80
    443
  ];
assert lib.all (
  host:
  production.services.nginx.virtualHosts.${host}.basicAuthFile == "/private/nginx/mon.htpasswd"
  &&
    production.services.nginx.virtualHosts.${host}.locations."= /codex/api/v1/query".basicAuthFile
    == "/var/lib/nginx-auth/prometheus-codex.htpasswd"
) hosts;
pkgs.runCommand "prometheus-query-access"
  {
    nativeBuildInputs = inputs;
    passthru = { inherit integration configFile; };
  }
  ''
    python3 ${./prometheus-query-access.py} --syntax ${configFile}
    touch "$out"
  ''
