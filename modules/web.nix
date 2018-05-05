{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.web;
  domain = cfg.domain;
  pinned = import ../pinned.nix { inherit lib pkgs; };

  docs = pkgs.runCommand "docsroot" { buildInputs = [ pinned.nixpkgsVpsFree.mkdocs ]; } ''
    mkdir -p $out
    pushd ${pinned.vpsadminosGit}
    mkdocs build --site-dir $out
    popd
    ls $out
  '';

  osctl_man = pkgs.runCommand "osctl_man" { buildInputs = [ pinned.vpsadminosDocsPkgs.osctl pkgs.git ]; } ''
    mkdir man
    cp -R ${pinned.vpsadminosGit} vpsadminos
    chmod -R +w vpsadminos
    pushd vpsadminos/osctl
      touch man/style.css
      osctl-env-exec rake md2man:web
      mkdir $out
      cp -R man/* $out/
    popd
    # hack around md2man unable to generate style.css due to creating
    # it readonly, which we workaround with touch which results in empty style..
    rm -rf $out/style.css
    cp $(osctl-env-exec 'bash -c "echo $BUNDLE_PATH"')/gems/md2man-*/lib/md2man/rakefile/style.css $out/style.css
  '';

  converter_man = pkgs.runCommand "converter_man" { buildInputs = [ pinned.vpsadminosDocsPkgs.osctl pkgs.git ]; } ''
    cp -R ${pinned.vpsadminosGit} vpsadminos
    chmod -R +w vpsadminos
    pushd vpsadminos/converter
      touch -d 1990-01-01 man/style.css
      osctl-env-exec rake md2man:web
      mkdir $out
      cp -R man/* $out/
    popd

    # same style hack as above
    rm -rf $out/style.css
    cp $(osctl-env-exec 'bash -c "echo $BUNDLE_PATH"')/gems/md2man-*/lib/md2man/rakefile/style.css $out/style.css
  '';

  man = pkgs.runCommand "manroot" { } ''
    mkdir $out
    ln -s ${osctl_man} $out/osctl
    ln -s ${converter_man} $out/converter
  '';

  ref = pkgs.runCommand "refroot" { buildInputs = [ pinned.vpsadminosDocsPkgs.osctl pkgs.git ]; } ''
    cp -R ${pinned.vpsadminosGit} vpsadminos
    chmod -R +w vpsadminos
    mkdir $out
    pushd vpsadminos
      for gem in libosctl osctl osctld converter ; do
        pushd $gem
          mkdir $out/$gem
          YARD_OUTPUT=$out/$gem osctl-env-exec rake yard
          test -f $out/$gem/index.html || (echo "gem $gem didn't produce index.html" && exit 1);
        popd
      done
    popd
  '';

  # XXX: if we decide to sign templates as well
  #templates_root = pkgs.runCommand "templatesroot" { buildInputs = [ pkgs.openssl ]; } ''
  #  mkdir -pv $out

  #  function signit {
  #    openssl cms -sign -binary -noattr -in $1 -signer ${../static/ca/codesign.crt} -inkey ${../static/ca/codesign.key} -certfile ${../static/ca/root.pem} -outform DER -out ''${1}.sig
  #  }
  #  signit $out/XYZ
  #'';

in
{
  options = {
    web = rec {
      domain = mkOption {
        type = types.str;
        description = "Domain of the webserver";
        default = config.global.domain;
      };

      acmeSSL = mkOption {
        type = types.bool;
        description = "Enable ACME and SSL for nginx";
        default = false;
      };
    };
  };

  config = {
    services.nginx = {
      enable = true;
      recommendedTlsSettings = cfg.acmeSSL;
      commonHttpConfig = "server_names_hash_bucket_size 32;";
      virtualHosts = {
        "${domain}" = {
          root = docs;
          forceSSL = cfg.acmeSSL;
          enableACME = cfg.acmeSSL;
        };

        "templates.${domain}" = {
          root = "/srv/templates";
          forceSSL = cfg.acmeSSL;
          enableACME = cfg.acmeSSL;
          locations = {
            "/" = {
              extraConfig = "autoindex on;";
            };
          };
        };

        "man.${domain}" = {
          root = man;
          forceSSL = cfg.acmeSSL;
          enableACME = cfg.acmeSSL;
          locations = {
            "/" = {
              extraConfig = "autoindex on;";
            };
          };
        };

        "ref.${domain}" = {
          root = ref;
          forceSSL = cfg.acmeSSL;
          enableACME = cfg.acmeSSL;
          locations = {
            "/" = {
              extraConfig = "autoindex on;";
            };
          };
        };
      };
    };

  };
}
