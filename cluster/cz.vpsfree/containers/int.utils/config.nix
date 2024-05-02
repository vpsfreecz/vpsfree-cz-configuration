{ config, pkgs, lib, confLib, ... }:
with lib;
let
  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking.firewall.extraCommands = ''
    # Allow access from proxy.prg
    iptables -A nixos-fw -p tcp --dport 80 -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept
  '';

  users = {
    users.adminer = {
      isSystemUser = true;
      createHome = true;
      group = "adminer";
    };
    groups.adminer = {};
  };

  services.phpfpm.pools.adminer = {
    user = "adminer";
    settings = {
      "listen.owner" = config.services.nginx.user;
      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.max_requests" = 500;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 5;
      "php_admin_value[error_log]" = "stderr";
      "php_admin_flag[log_errors]" = true;
      "catch_workers_output" = true;
    };
    phpEnv."PATH" = lib.makeBinPath [ pkgs.php ];
  };

  services.nginx = {
    enable = true;

    virtualHosts."utils.vpsfree.cz" = {
      locations."= /adminer/adminer.php" =
        let
          version = "4.8.1";

          script = pkgs.fetchurl {
            url = "https://github.com/vrana/adminer/releases/download/v${version}/adminer-${version}-en.php";
            sha256 = "sha256:0sqi537gcd957ycrp5h463dwlgvgw2zm2h2xb8miwmxv37k6phsf";
          };

          rootDir = pkgs.runCommand "adminer-root" {} ''
            mkdir -p $out/adminer
            ln -s ${script} $out/adminer.php
            ln -s ${script} $out/adminer/adminer.php
          '';
        in {
          root = rootDir;
          extraConfig = ''
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:${config.services.phpfpm.pools.adminer.socket};
            include ${pkgs.nginx}/conf/fastcgi_params;
            include ${pkgs.nginx}/conf/fastcgi.conf;
            fastcgi_index adminer.php;
          '';
        };
    };
  };

  system.stateVersion = "22.11";
}
