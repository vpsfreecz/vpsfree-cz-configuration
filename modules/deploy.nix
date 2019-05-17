{ config, lib, pkgs, ... }:
let
  customVim =
    pkgs.vim_configurable.customize {
        name = "vim";
        vimrcConfig.packages.myplugins = with pkgs.vimPlugins; {
          start = [ vim-nix sensible ]; # load plugin on startup
        };
    };
  home-manager-src = builtins.fetchTarball {
    url = "https://github.com/rycee/home-manager/archive/8b15f1899356762187ce119980ca41c0aba782bb.tar.gz";
    sha256 = "17bahz18icdnfa528zrgrfpvmsi34i859glfa595jy8qfap4ckng";
  };
in
{

  imports = [
    "${home-manager-src}/nixos"
    ./havesnippet.nix
  ];

  nixpkgs.overlays = import ../overlays;

  environment.systemPackages = with pkgs; [
    morph
    screen
    git
    git-crypt
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

  home-manager.useUserPackages = true;
  home-manager.users.srk = {
    home = {
      sessionVariables = {
        EDITOR = "vim";
      };
      packages = [ customVim ];
    };
    programs = {
      ssh = {
        enable = true;
        controlMaster = "auto";
        controlPersist = "1h";
        matchBlocks = import ../ssh-match-blocks.nix;
      };
    };
  };

  home-manager.users.aither = {
    home = {
      sessionVariables = {
        EDITOR = "vim";
      };
      packages = [ customVim ];
    };
    programs = {
      ssh = {
        enable = true;
        controlMaster = "auto";
        controlPersist = "1h";
        matchBlocks = import ../ssh-match-blocks.nix;
      };
    };
  };

  runit.services = lib.mapAttrs' (username: usercfg:
    lib.nameValuePair "home-manager-${username}" {
      run = ''
        echo Activating home-manager configuration for ${username}
        su -l -c ${usercfg.home.activationPackage}/activate ${username}
        sv once "home-manager-${username}"
      '';
    }) config.home-manager.users;
}
