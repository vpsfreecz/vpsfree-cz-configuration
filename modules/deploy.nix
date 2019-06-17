{ config, lib, pkgs, ... }:

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

  imports = [
    ./havesnippet.nix
  ];

  nixpkgs.overlays = import ../overlays;
  nix = {
    maxJobs = 8;
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
    git-crypt
    nix-prefetch-scripts
    customVim
  ];

  programs.havesnippet.enable = true;

  users.extraUsers.srk = {
    isNormalUser = true;
    createHome = true;
    uid = 1000;
  };

  users.extraUsers.srk.openssh.authorizedKeys.keys =
    with import ../ssh-keys.nix; [ srk_new ];

  users.extraUsers.aither = {
    isNormalUser = true;
    createHome = true;
    uid = 1001;
  };

  users.extraUsers.aither.openssh.authorizedKeys.keys =
    with import ../ssh-keys.nix; [ aither ];
}
