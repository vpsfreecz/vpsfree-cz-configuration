{ config, pkgs, lib, confLib, ... }:
let
  inherit (lib) nameValuePair listToAttrs;

  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  kbSites = [
    rec {
      name = "kb.vpsfree.cz";
      host = name;
      title = "Znalostní báze";
      tagline = "Informace o sdružení vpsFree.cz, návody a nejčastější dotazy.";
      start = "domů";
      lang = "cs";
      maintainersNamespace = "uzivatele";
      mlfarmMaster = false;
      matomoCodeFile = pkgs.writeText "matomo-kb.vpsfree.cz.html" ''
        <!-- Piwik -->
        <script type="text/javascript">
          var _paq = _paq || [];
          _paq.push(['trackPageView']);
          _paq.push(['enableLinkTracking']);
          (function() {
            var u="//piwik.vpsfree.cz/";
            _paq.push(['setTrackerUrl', u+'piwik.php']);
            _paq.push(['setSiteId', 5]);
            var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
            g.type='text/javascript'; g.async=true; g.defer=true; g.src=u+'piwik.js'; s.parentNode.insertBefore(g,s);
          })();
        </script>
        <noscript><p><img src="//piwik.vpsfree.cz/piwik.php?idsite=5" style="border:0;" alt="" /></p></noscript>
        <!-- End Piwik Code -->
      '';
    }

    rec {
      name = "kb.vpsfree.org";
      host = name;
      title = "Knowledge base";
      lang = "en";
      tagline = "Information about vpsFree.org, manuals and FAQs.";
      start = "home";
      maintainersNamespace = "users";
      mlfarmMaster = true;
      matomoCodeFile = pkgs.writeText "matomo-kb.vpsfree.org.html" ''
        <!-- Piwik -->
        <script type="text/javascript">
          var _paq = _paq || [];
          _paq.push(['trackPageView']);
          _paq.push(['enableLinkTracking']);
          (function() {
            var u="//piwik.vpsfree.cz/";
            _paq.push(['setTrackerUrl', u+'piwik.php']);
            _paq.push(['setSiteId', '7']);
            var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
            g.type='text/javascript'; g.async=true; g.defer=true; g.src=u+'piwik.js'; s.parentNode.insertBefore(g,s);
          })();
        </script>
        <noscript><p><img src="//piwik.vpsfree.cz/piwik.php?idsite=7" style="border:0;" alt="" /></p></noscript>
        <!-- End Piwik Code -->
      '';
    }
  ];

  kbPlugins = [
    # oauth
    (mkPlugin {
      name = "oauth";
      owner = "cosmocode";
      repo = "dokuwiki-plugin-oauth";
      rev = "d9f53e6ab63e09e2093f20d5a4510339fcac44da";
      sha256 = "sha256-jyyKEhKp6LyHIq8vmaS1WOc+uyNxwHMt0kmSTSuOGKo=";
    })
    # oauthgeneric
    (mkPlugin {
      name = "oauthgeneric";
      owner = "cosmocode";
      repo = "dokuwiki-plugin-oauthgeneric";
      rev = "602a0fb657303626e6233809531985981408b2f8";
      sha256 = "sha256-fVsAczzl0PCUT6J/SAZjtfx++GDJBEknv9W9vFt4Kf8=";
    })
    # maintainers
    (mkPlugin {
      name = "maintainers";
      owner = "vpsfreecz";
      repo = "dokuwiki-plugin-maintainers";
      rev = "1a4c84447ccead4a85f519de5847b31a579fbf37";
      sha256 = "sha256-ez3asV49dUotGMuzvUGLASG5q/Z4xP1yCMS9b8LWCQo=";
    })
    # matomo
    (mkPlugin {
      name = "matomo";
      owner = "Bravehartk2";
      repo = "dokuwiki-matomo";
      rev = "574ce29772458f8235b2a7c8ea09b658f577b8f9";
      sha256 = "sha256-OWyWDlu6Pe0pV10gpXGkGdJOUgRuVc3O926mQq2XnIQ=";
    })
    # mlfarm
    (mkPlugin {
      name = "mlfarm";
      owner = "vpsfreecz";
      repo = "dokuwiki-plugin-mlfarm";
      rev = "ee244dc3d7d12a767f444642f3897134277b278b";
      sha256 = "sha256-wnJdtCkTN/b5b4RAn51SaJQku/gaRTaBbsOAuKD3B5s=";
    })
    # sqlite
    (mkPlugin {
      name = "sqlite";
      owner = "cosmocode";
      repo = "sqlite";
      rev = "6cb8d74b9460386ebe827296478b5f3d5e4b00cb";
      sha256 = "sha256-Hfbh70bmhTWO64HTvWhK/fnivizr2oDuqurzQ/Tn5sQ=";
    })
    # wrap
    (mkPlugin {
      name = "wrap";
      owner = "selfthinker";
      repo = "dokuwiki_plugin_wrap";
      rev = "9c6c948e33d880fdf9583545439af9e3c1fabae4";
      sha256 = "sha256-XVmrIUVD0Q6F8BXByhYd0bKtvVK22LLpijVXHTrZD2k=";
    })
  ];

  mkPlugin = { name, owner, repo, rev, sha256 }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit name;
      src = pkgs.fetchFromGitHub {
        inherit owner repo rev sha256;
      };
      installPhase = ''
        mkdir -p $out
        cp -R ./* $out/
      '';
    };

  dokuwiki-template-vpsfree = pkgs.stdenvNoCC.mkDerivation rec {
    name = "dokuwiki-vpsfree";
    version = "2023-12-09";
    src = pkgs.fetchFromGitHub {
      owner = "vpsfreecz";
      repo = "dokuwiki-template-vpsfree";
      rev = "487c418e9ae28b9636e4311eb5f099f4b080dec6";
      sha256 = "sha256-Yt4QiGUJHjw0KeydBuCyLpP6rM7tI0i1CQTZYxgN+cU=";
    };
    installPhase = ''
      mkdir -p $out
      cp -R ./* $out/
    '';
  };

  mkSite = { name, host, title, lang, tagline, start, maintainersNamespace, mlfarmMaster, matomoCodeFile }: {
    enable = true;

    templates = [ dokuwiki-template-vpsfree ];

    plugins = kbPlugins;

    settings = {
      inherit title lang tagline start;
      baseurl = "https://${host}";
      disableactions = [ "register" "source" "export_raw" ];
      license = "cc-by-sa";
      template = "dokuwiki-vpsfree";
      superuser = "@admin";
      useacl = true;
      authtype = "oauth";
      userewrite = true;
      youarehere = true;
      remote = true;
      remoteuser = "";
      plugin = {
        maintainers = {
          user_ns = maintainersNamespace;
        };

        matomo = {
          track_admin_user = false;
          track_user = true;
          js_tracking_code._file = matomoCodeFile;
        };

        mlfarm = {
          master = mlfarmMaster;
          cache-file = "/var/lib/kb-shared/mlfarm/map.dat";
        };

        oauth = {
          register-on-auth = true;
          overwrite-groups = true;
        };

        oauthgeneric = {
          key = name;
          secret._file = "/private/kb/${name}.client_secret";
          authurl = "https://auth.vpsfree.cz/_auth/oauth2/authorize";
          tokenurl = "https://auth.vpsfree.cz/_auth/oauth2/token";
          userurl = "https://api.vpsfree.cz/users/current";
          scopes._raw = "array()";
          authmethod = 1; # bearer token
          needs-state = true;
          json-user = "response.user.login";
          json-name = "response.user.full_name";
          json-mail = "response.user.email";
          json-grps = "response.user.dokuwiki_groups";
          label = "vpsAdmin";
        };
      };
    };

    usersFile = "/private/kb/users.auth.php";

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
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking.firewall.extraCommands = ''
    # Allow access from proxy.prg
    iptables -A nixos-fw -p tcp --dport 80 -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept
    iptables -A nixos-fw -p tcp --dport 80 -s 172.16.107.0/24 -j nixos-fw-accept
  '';

  # We use a shared media folder, as the images between the two KBs are mostly
  # the same
  systemd.tmpfiles.rules = [
    "d /var/lib/kb-shared 0755 root root - -"
    "d /var/lib/kb-shared/media 0750 dokuwiki nginx - -"
    "d /var/lib/kb-shared/mlfarm 0750 dokuwiki nginx - -"
  ];

  fileSystems = listToAttrs (map (site:
    nameValuePair "${config.services.dokuwiki.sites.${site.name}.stateDir}/media" {
      device = "/var/lib/kb-shared/media";
      options = [ "bind" ];
    }
  ) kbSites);

  services.dokuwiki = {
    webserver = "nginx";

    sites = listToAttrs (map (site: nameValuePair site.name (mkSite site)) kbSites);
  };

  system.stateVersion = "23.05";
}
