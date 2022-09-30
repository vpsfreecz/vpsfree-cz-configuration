{ config, pkgs, lib, confLib, confMachine, ... }:
with lib;
let
  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  mailingLists = [ "community" "news" "outage" ];

  getUid = instance:
    let name = config.services.vpsfree-irc-bot.instances.${instance}.user;
    in config.users.users.${name}.uid;

  getGid = instance:
    let name = config.services.vpsfree-irc-bot.instances.${instance}.group;
    in config.users.groups.${name}.gid;

  botUser = config.services.vpsfree-irc-bot.instances.libera.user;
  botGroup = config.services.vpsfree-irc-bot.instances.libera.user;
  botUid = getUid "libera";
  botGid = getGid "libera";

  archiveDir = "/var/vpsfbot-archive";

in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking.firewall.extraCommands = ''
    # Allow access from im.vpsfree.cz
    iptables -A nixos-fw -p tcp --dport 80 -s 37.205.9.40 -j nixos-fw-accept

    # Allow access from proxy.prg
    iptables -A nixos-fw -p tcp --dport 8000 -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept
  '';

  systemd.tmpfiles.rules = [
    "d '${archiveDir}' 0750 ${botUser} ${config.services.nginx.group} - -"
  ];

  services.vpsfree-irc-bot = {
    enable = true;
    instances.libera = {
      extraConfigFiles = [ "/private/vpsfbot/libera.yml" ];

      settings = {
        server = {
          label = "irc.libera.chat";
          host = "irc.libera.chat";
        };

        channels = [
          "#vpsfree"
          "#vpsadminos"
        ];

        nick = "vpsfbot";

        archive_url = "https://im.vpsfree.cz/archive/";
        archive_dst = archiveDir;

        mailing_lists = {
          channels = [
            "#vpsfree"
          ];
        };

        dokuwiki = [
          {
            url = "https://kb.vpsfree.cz";
            namespace_slash = true;
            rewrite = 1;
            prefix = "[KB]";
            channels = [
              "#vpsfree"
            ];
          }
          {
            url = "https://kb.vpsfree.org";
            namespace_slash = true;
            rewrite = 1;
            prefix = "[KB]";
            channels = [
              "#vpsfree"
            ];
          }
        ];

        blog = {
          url = "https://blog.vpsfree.cz/feed/";
          channels = [
            "#vpsfree"
          ];
        };

        outage_reports = {
          channels = [
            "#vpsfree"
          ];
        };

        web_event_log = {
          channels = [
            "#vpsfree"
          ];
        };

        github_webhook = {
          host = "0.0.0.0";
          port = 8000;
          channels = {
            "#vpsfree" = [
              "vpsfreecz/oficialni-dokumenty"
              "vpsfreecz/vpsfree-client"
              "vpsfreecz/vpsfree-cz-configuration"
              "vpsfreecz/vpsfree-mail-templates"
              "vpsfreecz/web"
            ];
            "#vpsadminos" = [
              "vpsfreecz/confctl"
              "vpsfreecz/haveapi"
              "vpsfreecz/htop"
              "vpsfreecz/linux"
              "vpsfreecz/lxc"
              "vpsfreecz/lxcfs"
              "vpsfreecz/nixos-modules"
              "vpsfreecz/terraform-provider-vpsadmin"
              "vpsfreecz/vpsfree-cz-configuration"
              "vpsfreecz/vpsadmin"
              "vpsfreecz/vpsadmin-go-client"
              "vpsfreecz/vpsadminos"
              "vpsfreecz/vpsadminos-image-build-scripts"
              "vpsfreecz/vpsadminos-org-configuration"
              "vpsfreecz/zfs"
            ];
          };
        };
      };
    };
  };

  services.nginx = {
    enable = true;

    virtualHosts."vpsfbot.vpsfree.cz" = {
      locations."/archive" = {
        root = pkgs.runCommand "vpsfbot-archive-root" {} ''
          mkdir $out
          ln -s ${archiveDir}/html $out/archive
        '';
        extraConfig = ''
          autoindex on;
        '';
      };
    };
  };

  system.stateVersion = "22.05";
}
