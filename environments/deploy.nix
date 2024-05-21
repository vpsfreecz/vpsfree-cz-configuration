{ config, lib, pkgs, confMachine, ... }:

let
  customVim =
    pkgs.vim-full.customize {
      name = "myvim";
      vimrcConfig.packages.myplugins = with pkgs.vimPlugins; {
        start = [ vim-nix sensible ]; # load plugin on startup
      };
    };

  alerters = [
    "https://alerts1.prg.vpsfree.cz"
    "https://alerts2.prg.vpsfree.cz"
  ];

  httpConfigFile = pkgs.writeText "am-http-config.yml" (builtins.toJSON {
    basic_auth = {
      username = "build";
      password_file = "/secrets/alertmanager-http-password";
    };
  });
in
{
  nix.settings = {
    sandbox = true;
    extra-sandbox-paths = [
      "/nix/var/cache/ccache"
      "/secrets/nodes/images"
    ];
    cores = 0;
    gc-keep-outputs = true;
    gc-keep-derivations = true;
  };

  environment.enableDebugInfo = true;

  environment.shellAliases = {
    gg = "git grep -i";
    vim = lib.mkForce "myvim";
  };

  environment.etc = {
    "amtool/config.yml".text = builtins.toJSON {
      "alertmanager.url" = builtins.elemAt alerters 0;
      "author" = confMachine.host.fqdn;
      "require-comment" = false;
      "http.config.file" = httpConfigFile;
    };
  };

  environment.systemPackages = with pkgs; [
    prometheus-alertmanager
    asciinema
    screen
    git
    nix-prefetch-scripts
    customVim

    (pkgs.writeScriptBin "generate-node-secrets" ''
      set -e
      test $# -eq 1 || { echo "Expects node hostname"; exit 1; }
      test -d /secrets/nodes/images/"''${1}" && { echo "Already there"; exit 1; }
      mkdir -p /secrets/nodes/images/"''${1}"/secrets
      cp -rp /secrets/nodes/template/ /secrets/nodes/images/"''${1}"/secrets/
      ssh-keygen -t rsa -b 4096 -f /secrets/nodes/images/"''${1}"/secrets/ssh_host_rsa_key -N ""
      ssh-keygen -t ed25519 -f /secrets/nodes/images/"''${1}"/secrets/ssh_host_ed25519_key -N ""
      chmod 0644 /secrets/nodes/images/"''${1}"/secrets/ssh_host_*
    '')

    (pkgs.writeScriptBin "update-node-secrets" ''
      set -e
      for dir in /secrets/nodes/images/*/secrets ; do
        cp -rp /secrets/nodes/template/* $dir/
      done
    '')

    (pkgs.writeScriptBin "upload-node-secrets" ''
      set -e

      for fqdn in "$@" ; do
        echo "''${fqdn}:"
        ${pkgs.rsync}/bin/rsync -rltgoDv "/secrets/nodes/images/$fqdn/secrets/" ''${fqdn}:/var/secrets/
      done
    '')
  ];
}
