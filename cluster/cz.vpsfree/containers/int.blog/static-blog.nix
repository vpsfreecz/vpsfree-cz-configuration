{
  config,
  lib,
  pkgs,
  confLib,
  ...
}:
let
  cfg = config.services.vpsfree-static-blog;
  state = "/var/lib/blog";
  proxy = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
  portAllowed =
    firewall:
    lib.elem 8080 firewall.allowedTCPPorts
    || lib.any (range: range.from <= 8080 && range.to >= 8080) firewall.allowedTCPPortRanges;
  helper = pkgs.writeShellApplication {
    name = "blog-static-release";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../../../../tools/blog-static-release.py} "$@"
    '';
  };
  vhost = language: {
    listen = [
      {
        addr = "0.0.0.0";
        port = 8080;
      }
    ];
    root = "${state}/current/${language}";
    locations."/".tryFiles = "$uri $uri/ =404";
    locations."= /feed/" = {
      alias = "${state}/current/${language}/feed/index.xml";
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
    enable = lib.mkEnableOption "the inactive static blog hosting candidate";
    pull = {
      enable = lib.mkEnableOption "scheduled activation (blocked pending installed machine admission)";
      workflowId = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
        description = "Independently verified GitHub workflow ID; not yet provisioned.";
      };
      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Runtime read-only artifact credential file; never stored in Nix.";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.pull.enable;
        message = "Static blog scheduled activation is blocked: installed machine-coordination admission is not integrated.";
      }
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
    ];
    environment.systemPackages = [ helper ];
    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -w -A nixos-fw -p tcp \
        -s ${proxy.addresses.primary.address}/32 --dport 8080 -j nixos-fw-accept
    '';
    services.nginx.virtualHosts = {
      "static-blog-cs" = (vhost "cs") // {
        serverName = "blog.vpsfree.cz";
      };
      "static-blog-en" = (vhost "en") // {
        serverName = "blog.vpsfree.org";
      };
      "static-blog-unknown-host" = {
        serverName = "_";
        listen = [
          {
            addr = "0.0.0.0";
            port = 8080;
            default = true;
          }
        ];
        locations."/".return = "444";
      };
    };
    # No activation service is wanted by any target. Its CLI is fenced too.
    systemd.services.blog-static-pull = {
      description = "Static blog pull driver (machine admission unavailable)";
      serviceConfig = {
        Type = "oneshot";
        User = "blog-release";
        Group = "blog-release";
        UMask = "0077";
        ExecStart = "${helper}/bin/blog-static-release pull --state-dir ${state}";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ state ];
      };
    };
    systemd.timers = lib.mkIf cfg.pull.enable {
      blog-static-pull = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5m";
          OnUnitActiveSec = "15m";
        };
      };
    };
  };
}
