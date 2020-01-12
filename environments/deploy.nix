{ config, lib, pkgs, data, ... }:

let
  customVim =
    pkgs.vim_configurable.customize {
        name = "myvim";
        wrapManual = false;
        vimrcConfig.packages.myplugins = with pkgs.vimPlugins; {
          start = [ vim-nix sensible ]; # load plugin on startup
        };
    };
in
{
  nixpkgs.overlays = import ../overlays;
  nix = {
    maxJobs = 4;
    useSandbox = true;
    sandboxPaths = [ "/secrets/image/secrets" ];
    buildCores = 0;
    extraOptions =
     ''
       gc-keep-outputs = true
       gc-keep-derivations = true
     '';
  };

  environment.shellAliases = {
    gg = "git grep -i";
    vim = lib.mkForce "myvim";
  };

  environment.systemPackages = with pkgs; [
    morph
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

  programs.havesnippet.enable = true;
}
