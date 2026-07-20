{ pkgs }:

let
  wordpress_7_0_2 = pkgs.wordpress.override {
    version = "7.0.2";
    hash = "sha256-1KTSGd6mTGxo5i8v/D8zHFR1UQJG1sRPYftS83fSlbk=";
  };

  wordpress = wordpress_7_0_2.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      install -Dm0444 ${./vpsfree-policy.php} \
        "$out/share/wordpress/wp-content/mu-plugins/vpsfree-policy.php"
    '';
  });

  plugins = {
    akismet = pkgs.fetchzip {
      url = "https://downloads.wordpress.org/plugin/akismet.5.7.zip";
      hash = "sha256-sdxdqiXqjVL9yEG4QfBT9tOIK+zeQYBTxGcDz4XhyCw=";
    };

    "disable-gutenberg" = pkgs.fetchzip {
      url = "https://downloads.wordpress.org/plugin/disable-gutenberg.3.3.2.zip";
      hash = "sha256-b2vDWuqX9xv61TiH/nMzczSVDDZVn3Zv9y2qP5S9GAw=";
    };

    "wonderm00ns-simple-facebook-open-graph-tags" = pkgs.fetchzip {
      url = "https://downloads.wordpress.org/plugin/wonderm00ns-simple-facebook-open-graph-tags.3.4.0.zip";
      hash = "sha256-rJYeNudcQFoVqvy3VhEScp0TJ0qwKnmnxsswQJCdKsQ=";
    };
  };

  coreCsCz = pkgs.fetchzip {
    url = "https://downloads.wordpress.org/translation/core/7.0.2/cs_CZ.zip";
    hash = "sha256-eMlk19T2KxuMxptSrMAFVzmZuUFxs30upOv4Wz5gHiw=";
    stripRoot = false;
  };

  akismetCsCz = pkgs.fetchzip {
    url = "https://downloads.wordpress.org/translation/plugin/akismet/5.7/cs_CZ.zip";
    hash = "sha256-Ki6DeO6N8/NjBy7B07paJV5W9vbrJ5pTXLNpKaNRqy0=";
    stripRoot = false;
  };

  bootstrapJs = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/twbs/bootstrap/v3.4.1/dist/js/bootstrap.min.js";
    hash = "sha256-nuL8/2cJ5NDSSwnKD8VqreErSWHtnEP9E7AySL+1ev4=";
  };

  csCz = pkgs.runCommand "wordpress-languages-cs-CZ-7.0.2" { } ''
    mkdir -p "$out"
    cp -a ${coreCsCz}/. "$out/"

    chmod u+w "$out"
    mkdir -p "$out/plugins" "$out/themes"
    cp -a ${akismetCsCz}/. "$out/plugins/"
    install -m0444 ${./flat-cs_CZ.mo} "$out/themes/flat-cs_CZ.mo"
  '';

  flat = pkgs.wordpressPackages.mkWordpressDerivation {
    type = "theme";
    pname = "flat";
    version = "6.6.6";
    license = "gpl3Plus";
    src = ./flat;
    postInstall = ''
      install -m0444 ${bootstrapJs} "$out/assets/js/bootstrap-3.4.1.min.js"
    '';
  };

  themes = {
    inherit flat;
    inherit (pkgs.wordpressPackages.themes) twentytwentyfive;
  };
in
{
  inherit wordpress plugins themes;
  languages = [ csCz ];
}
