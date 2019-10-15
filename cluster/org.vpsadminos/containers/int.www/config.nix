{ config, pkgs, lib, confLib, data, ... }:
let
  proxy = confLib.findConfig {
    cluster = config.cluster;
    domain = "org.vpsadminos";
    location = null;
    name = "proxy";
  };

  swpins = import ../../../../swpins { name = "www.int.vpsadminos.org"; inherit lib pkgs; };

  docsOs = swpins.vpsadminos-runtime-deps;

  docsPkgs = import swpins.nixpkgs {
    overlays = [
      (import ("${docsOs}/os/overlays/osctl.nix"))
      (import ("${docsOs}/os/overlays/ruby.nix"))
    ];
  };

  docs = pkgs.runCommand "docsroot" { buildInputs = [ docsPkgs.mkdocs ]; } ''
    mkdir -p $out
    pushd ${swpins.vpsadminos}
    mkdocs build --site-dir $out
    popd
  '';

  buildMan = component: pkgs.runCommand "${lib.replaceStrings ["/"] ["_"] component}_man" {
    buildInputs = [ docsPkgs.osctl-env-exec pkgs.git ];
  } ''
    # Necessary for unicode characters in manpages
    export LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"
    export LANG="en_US.UTF-8"

    mkdir man
    cp -R ${swpins.vpsadminos} vpsadminos
    chmod -R +w vpsadminos
    pushd vpsadminos/${component}
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

  man = pkgs.runCommand "manroot" { } ''
    mkdir $out
    ln -s ${buildMan "osctl"} $out/osctl
    ln -s ${buildMan "osctl-exportfs"} $out/osctl-exportfs
    ln -s ${buildMan "osctl-image"} $out/osctl-image
    ln -s ${buildMan "osctl-repo"} $out/osctl-repo
    ln -s ${buildMan "converter"} $out/converter
    ln -s ${buildMan "osup"} $out/osup
    ln -s ${buildMan "svctl"} $out/svctl
  '';

  refGems = pkgs.runCommand "ref-gems" {
    buildInputs = [ docsPkgs.osctl-env-exec pkgs.git ];
  } ''
    cp -R ${swpins.vpsadminos} vpsadminos
    chmod -R +w vpsadminos
    mkdir $out
    pushd vpsadminos
      for gem in libosctl osctl osctl-exportfs osctl-image osctl-repo osctld converter svctl; do
        pushd $gem
          mkdir -p $out/$gem
          YARD_OUTPUT=$out/$gem osctl-env-exec rake yard
          test -f $out/$gem/index.html || (echo "gem $gem didn't produce index.html" && exit 1);
        popd
      done
    popd
  '';

  osManual = import "${swpins.vpsadminos}/os/manual" { inherit pkgs; };

  refOs = pkgs.runCommand "ref-os" {} ''
   mkdir $out
   ln -s ${osManual.html}/share/doc/vpsadminos $out/os
  '';

  ref = pkgs.buildEnv {
    name = "refroot";
    paths = [
      refGems
      refOs
    ];
  };
in
{
  imports = [
    ../../../../environments/base.nix
  ];

  networking = {
    firewall.extraCommands = ''
      # Allow access from proxy
      iptables -A nixos-fw -p tcp --dport 80 -s ${proxy.addresses.primary.address} -j nixos-fw-accept
    '';
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      "www.vpsadminos.org" = {
        root = docs;
        default = true;
      };

      "man.vpsadminos.org" = {
        root = man;
        locations = {
          "/" = {
            extraConfig = "autoindex on;";
          };
        };
      };

      "ref.vpsadminos.org" = {
        root = ref;
        locations = {
          "/" = {
            extraConfig = "autoindex on;";
          };
        };
      };
    };
  };
}
