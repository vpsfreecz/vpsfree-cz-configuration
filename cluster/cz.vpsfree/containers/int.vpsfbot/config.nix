{ config, pkgs, lib, confLib, confMachine, ... }:
with lib;
let
  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  mntLists = "/mnt/lists";

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

  nixpkgs.overlays = import ../../../../overlays;

  # Mount mailing list archives so that the bot can locate messages
  # Note that this requires that root's public key is authorized on prasiatko
  boot.postBootCommands = concatMapStringsSep "\n" (name: "mkdir -p ${mntLists}/${name}-list") mailingLists;

  system.fsPackages = with pkgs; [ sshfs ];

  fileSystems = listToAttrs (map (name: nameValuePair "${mntLists}/${name}-list" {
    device = "vpsfbot@prasiatko.int.vpsfree.cz:/var/lib/mailman/archives/private/${name}-list";
    fsType = "fuse.sshfs";
    options = [
      "defaults"
      "_netdev"
      "uid=${toString botUid}"
      "gid=${toString botGid}"
      "reconnect"
      "ro"
    ];
  }) mailingLists);

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
          archive_dir = mntLists;
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
              "vpsfreecz/web"
              "vpsfreecz/oficialni-dokumenty"
              "vpsfreecz/vpsfree-mail-templates"
              "vpsfreecz/vpsfree-cz-configuration"
            ];
            "#vpsadminos" = [
              "vpsfreecz/vpsadmin"
              "vpsfreecz/vpsadminos"
              "vpsfreecz/nixpkgs"
              "vpsfreecz/lxc"
              "vpsfreecz/lxcfs"
              "vpsfreecz/zfs"
              "vpsfreecz/nixops"
              "vpsfreecz/htop"
              "vpsfreecz/vpsadminos-image-build-scripts"
              "vpsfreecz/linux"
              "vpsfreecz/haveapi"
              "vpsfreecz/vpsadmin-go-client"
              "vpsfreecz/pty-wrapper"
              "vpsfreecz/data-prometheus"
              "vpsfreecz/machine-check"
              "vpsfreecz/nixos-modules"
              "vpsfreecz/haskell-zre"
              "vpsfreecz/terraform-provider-vpsadmin"
              "vpsfreecz/vpsfree-cz-configuration"
              "vpsfreecz/confctl"
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
}
