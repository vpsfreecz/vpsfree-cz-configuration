{ config, pkgs, lib, confLib, confData, confMachine, swpins, ... }:
let
  ns1IntPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.ns1";
  };

  ns1IntBrq = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/brq/int.ns1";
  };

  internalDns = [ ns1IntPrg ns1IntBrq ];

  internalDnsAddresses = map (m: m.addresses.primary.address) internalDns;
in {
  # NOTE: environments/base.nix is not imported, this is a standalone system
  imports = [
    ./hardware.nix
    "${builtins.fetchTarball https://github.com/nix-community/home-manager/archive/release-23.11.tar.gz}/nixos"
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  networking.useDHCP = false;
  networking.interfaces.enp1s0.ipv4.addresses = [{ address = "172.16.106.16"; prefixLength = 24; }];
  networking.defaultGateway = "172.16.106.1";
  networking.nameservers = internalDnsAddresses ++ [ "172.16.106.1" ];

  nix.nixPath = [ "nixpkgs=${swpins.nixpkgs}" ];

  nixpkgs.overlays = import ../../../../overlays;

  time.timeZone = "Europe/Amsterdam";

  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  users.users.root.openssh.authorizedKeys.keys = confData.sshKeys.builders ++ confData.sshKeys.aither.all;

  users.users.aither = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = confData.sshKeys.aither.all;
  };

  environment.systemPackages = with pkgs; [
    vim
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  programs.vim.defaultEditor = true;

  programs.bepastyrb.enable = true;

  system.monitoring.enable = false;

  home-manager.users.aither = { config, ... }: {
    programs.home-manager.enable = true;

    home.stateVersion = "23.11";

    home.packages = with pkgs; [
      asciinema
      bind
      bundix
      bundler
      cloc
      git
      inetutils
      nix-prefetch-git
      openssl
      screen
      tmux
      unzip
      vpsfree-client
    ];

    home.file = {
      ".gitconfig".text = ''
        [user]
          name = Jakub Skokan
          email = jakub.skokan@havefun.cz

        [push]
          default = current
      '';
    };

    programs.bash = {
      enable = true;
      historySize = 10000;
      historyFileSize = 10000;
    };

    programs.tmux = {
      enable = true;
      extraConfig = ''
        set -g mouse on
        setw -g mode-keys vi
      '';
    };
  };

  system.stateVersion = "23.11";
}
