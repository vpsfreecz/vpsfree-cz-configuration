{ lib, pkgs, ... }:
let
  hostAddress = "192.168.123.1";
  localAddress = "192.168.123.2";

  kbStagingContainerctl = pkgs.writeShellScriptBin "kb-staging-containerctl" ''
    set -euo pipefail

    if [ "$#" -ne 1 ]; then
      echo "usage: kb-staging-containerctl start|stop|clear" >&2
      exit 2
    fi

    case "$1" in
      start|stop)
        exec ${pkgs.nixos-container}/bin/nixos-container "$1" kb-staging
        ;;
      clear)
        exec ${pkgs.nixos-container}/bin/nixos-container \
          run kb-staging -- kb-staging-clear
        ;;
      *)
        echo "unknown action: $1" >&2
        exit 2
        ;;
    esac
  '';

  mkPlugin =
    {
      name,
      owner,
      repo,
      rev,
      sha256,
    }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit name;
      src = pkgs.fetchFromGitHub {
        inherit
          owner
          repo
          rev
          sha256
          ;
      };
      installPhase = ''
        mkdir -p $out
        cp -R ./* $out/
      '';
    };

  plugins = [
    (mkPlugin {
      name = "maintainers";
      owner = "vpsfreecz";
      repo = "dokuwiki-plugin-maintainers";
      rev = "1a4c84447ccead4a85f519de5847b31a579fbf37";
      sha256 = "sha256-ez3asV49dUotGMuzvUGLASG5q/Z4xP1yCMS9b8LWCQo=";
    })
    (mkPlugin {
      name = "mlfarm";
      owner = "vpsfreecz";
      repo = "dokuwiki-plugin-mlfarm";
      rev = "ee244dc3d7d12a767f444642f3897134277b278b";
      sha256 = "sha256-wnJdtCkTN/b5b4RAn51SaJQku/gaRTaBbsOAuKD3B5s=";
    })
    (mkPlugin {
      name = "note";
      owner = "lpaulsen93";
      repo = "dokuwiki_note";
      rev = "86cd79fb7c4be03be652e4e9f58f87b4ab965fec";
      sha256 = "sha256-y2BWI0+EZak2tDyNVdxWV5YLOSqitOD8nPcAx4aCSeU=";
    })
    (mkPlugin {
      name = "sqlite";
      owner = "cosmocode";
      repo = "sqlite";
      rev = "6cb8d74b9460386ebe827296478b5f3d5e4b00cb";
      sha256 = "sha256-Hfbh70bmhTWO64HTvWhK/fnivizr2oDuqurzQ/Tn5sQ=";
    })
    (mkPlugin {
      name = "vshare";
      owner = "splitbrain";
      repo = "dokuwiki-plugin-vshare";
      rev = "0f046031bdc0e13650dff209185adb2c6a330071";
      sha256 = "sha256-uDdSQzJlHIThA6fXvXwaodUQDe6A2pmapITrVn3eQyE=";
    })
    (mkPlugin {
      name = "wrap";
      owner = "selfthinker";
      repo = "dokuwiki_plugin_wrap";
      rev = "9c6c948e33d880fdf9583545439af9e3c1fabae4";
      sha256 = "sha256-XVmrIUVD0Q6F8BXByhYd0bKtvVK22LLpijVXHTrZD2k=";
    })
  ];

  template = pkgs.stdenvNoCC.mkDerivation {
    name = "dokuwiki-vpsfree-2023-12-09";
    src = pkgs.fetchFromGitHub {
      owner = "vpsfreecz";
      repo = "dokuwiki-template-vpsfree";
      rev = "9e90fa56bcc65d405e4019936a50d65a98fde169";
      sha256 = "sha256-RWO8Gn4F5r5pLhiCESbbj3d0Z3J9ImHHAnC+uqV1Xto=";
    };
    installPhase = ''
      mkdir -p $out
      cp -R ./* $out/
    '';
  };

  sites = [
    {
      name = "kb-cs.aitherdev.int.vpsfree.cz";
      title = "Znalostní báze – staging";
      tagline = "Interní kontrolní kopie kb.vpsfree.cz";
      start = "domů";
      lang = "cs";
      maintainersNamespace = "uzivatele";
      mlfarmMaster = false;
      usersFile = "/private/kb-staging/cz.users.auth.php";
    }
    {
      name = "kb-en.aitherdev.int.vpsfree.cz";
      title = "Knowledge base – staging";
      tagline = "Internal review copy of kb.vpsfree.org";
      start = "home";
      lang = "en";
      maintainersNamespace = "users";
      mlfarmMaster = true;
      usersFile = "/private/kb-staging/org.users.auth.php";
    }
  ];
in
{
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-kb-staging" ];
    externalInterface = "br0";
  };

  systemd.tmpfiles.rules = [
    "d /home/aither/.local/state/kb-stage 0700 aither users - -"
    "d /home/aither/.local/state/kb-stage/credentials 0755 aither users - -"
  ];

  environment.systemPackages = [ kbStagingContainerctl ];

  security.sudo.extraRules = lib.mkAfter [
    {
      users = [ "aither" ];
      commands =
        map
          (action: {
            command = "/run/current-system/sw/bin/kb-staging-containerctl ${action}";
            options = [ "NOPASSWD" ];
          })
          [
            "start"
            "stop"
            "clear"
          ];
    }
  ];

  containers.kb-staging = {
    autoStart = false;
    privateNetwork = true;
    inherit hostAddress localAddress;

    bindMounts."/private/kb-staging" = {
      hostPath = "/home/aither/.local/state/kb-stage/credentials";
      isReadOnly = true;
    };

    config =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        inherit (lib) listToAttrs nameValuePair;

        mkSite = site: {
          stateDir = "/var/lib/dokuwiki/${site.name}";
          templates = [ template ];
          inherit plugins;
          settings = {
            inherit (site)
              title
              tagline
              start
              lang
              ;
            baseurl = "http://${site.name}";
            disableactions = [
              "register"
              "source"
              "export_raw"
            ];
            license = "cc-by-sa";
            template = "dokuwiki-vpsfree";
            superuser = "@admin";
            useacl = true;
            authtype = "authplain";
            userewrite = true;
            useslash = true;
            youarehere = true;
            useheading = "1";
            remote = true;
            remoteuser = "";
            plugin = {
              maintainers.user_ns = site.maintainersNamespace;
              mlfarm = {
                master = site.mlfarmMaster;
                cache-file = "/var/lib/kb-shared/mlfarm/map.dat";
              };
            };
          };
          inherit (site) usersFile;
          acl = [
            {
              page = "*";
              actor = "@ALL";
              level = "read";
            }
            {
              page = "*";
              actor = "@user";
              level = "upload";
            }
            {
              page = "private:*";
              actor = "@ALL";
              level = "none";
            }
          ];
        };

        clearState = pkgs.writeShellScriptBin "kb-staging-clear" ''
          set -euo pipefail

          systemctl stop nginx.service
          ${lib.concatMapStringsSep "\n" (site: "systemctl stop phpfpm-dokuwiki-${site.name}.service") sites}
          ${lib.concatMapStringsSep "\n" (
            site:
            "find /var/lib/dokuwiki/${site.name} -mindepth 1 -maxdepth 1 ! -name media -exec rm -rf -- {} +"
          ) sites}
          find /var/lib/kb-shared/media -mindepth 1 -delete
          find /var/lib/kb-shared/mlfarm -mindepth 1 -delete
          systemd-tmpfiles --create
          ${lib.concatMapStringsSep "\n" (site: "systemctl start phpfpm-dokuwiki-${site.name}.service") sites}
          systemctl start nginx.service
        '';
      in
      {
        networking = {
          useHostResolvConf = lib.mkForce false;
          nameservers = [ hostAddress ];
          firewall.allowedTCPPorts = [ 80 ];
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/kb-shared 0755 root root - -"
          "d /var/lib/kb-shared/media 0750 dokuwiki nginx - -"
          "d /var/lib/kb-shared/mlfarm 0750 dokuwiki nginx - -"
        ];

        fileSystems = listToAttrs (
          map (
            site:
            nameValuePair "${config.services.dokuwiki.sites.${site.name}.stateDir}/media" {
              device = "/var/lib/kb-shared/media";
              fsType = "none";
              options = [ "bind" ];
            }
          ) sites
        );

        environment.systemPackages = [ clearState ];

        services.dokuwiki = {
          webserver = "nginx";
          sites = listToAttrs (map (site: nameValuePair site.name (mkSite site)) sites);
        };

        services.nginx.virtualHosts = listToAttrs (
          map (
            site:
            nameValuePair site.name {
              locations."~ \\.php$".extraConfig = ''
                fastcgi_param HTTP_AUTHORIZATION $http_authorization;
              '';
            }
          ) sites
        );

        system.stateVersion = "26.05";
      };
  };

  services.nginx.virtualHosts = builtins.listToAttrs (
    map (site: {
      name = site.name;
      value = {
        listen = [
          {
            addr = "172.16.106.40";
            port = 80;
          }
        ];
        locations."/".proxyPass = "http://${localAddress}:80";
      };
    }) sites
  );
}
