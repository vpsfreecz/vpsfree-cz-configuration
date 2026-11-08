{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.vpsfree-static-blog;
  state = "/var/lib/blog";
  portAllowed =
    firewall:
    lib.elem 8080 firewall.allowedTCPPorts
    || lib.any (range: range.from <= 8080 && range.to >= 8080) firewall.allowedTCPPortRanges;
  vhost = language: {
    extraConfig = "absolute_redirect off;";
    listen = [
      {
        addr = "127.0.0.1";
        port = 8080;
      }
    ];
    root = "${state}/current/${language}";
    locations."/".tryFiles = "$uri $uri/ =404";
    locations."= /feed/" = {
      # Select a regular-file URI before nginx's slash-URI index phase.
      tryFiles = "/feed/index.xml =404";
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
    enable = lib.mkEnableOption "the isolated static blog listener and storage";

  };
  config = lib.mkIf cfg.enable {
    assertions = [
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
    services.nginx.virtualHosts = {
      "static-blog-cs" = (vhost "cs") // {
        serverName = "blog.vpsfree.cz";
      };
      "static-blog-en" = (vhost "en") // {
        serverName = "blog.vpsfree.org";
      };
      "static-blog-unknown-host" = {
        serverName = "_";
        default = true;
        listen = [
          {
            addr = "127.0.0.1";
            port = 8080;
          }
        ];
        locations."/".return = "444";
      };
    };

  };
}
