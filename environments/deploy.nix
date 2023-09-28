{ config, lib, pkgs, confMachine, ... }:

let
  customVim =
    pkgs.vim_configurable.customize {
        name = "myvim";
        wrapManual = false;
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
      "/secrets/image/secrets"
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

    (pkgs.writeScriptBin "generate-node-sshkeys" ''
        set -e
        test $# -eq 1 || { echo "Expects node hostname"; exit 1; }
        test -d /secrets/nodes/"''${1}" && { echo "Already there"; exit 1; }
        mkdir -p /secrets/nodes/"''${1}"/ssh
        ssh-keygen -t rsa -b 4096 -f /secrets/nodes/"''${1}"/ssh/ssh_host_rsa_key -N ""
        ssh-keygen -t ed25519 -f /secrets/nodes/"''${1}"/ssh/ssh_host_ed25519_key -N ""
      '')

  ];
}
