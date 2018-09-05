{ config, lib, pkgs, ...}:
{

  imports = [
    ./bird.nix
  ];
  # XXX: include devel keys for now
  users.users.root.openssh.authorizedKeys.keys = with import ../ssh-keys.nix; [ aither snajpa snajpa_devel srk srk_devel ];
  # XXX: XXX
  users.users.root.initialHashedPassword = "$6$AOZFDbq4EDX3p$tjWxIS9/0ZcF6/Q30LtMB0/2sAz6taxbUTtraVLVOe7zORC7AernhNWbgLBj9OAZh1wTMhd1BW9NmIU9d7gj3.";

  boot.kernelModules = [
    "ipmi_si"
    "ipmi_devintf"
  ];

  boot.extraModulePackages = [ config.boot.kernelPackages.wireguard ];

  vpsadminos.nix = true;
  environment.systemPackages = with pkgs; [
    dmidecode
    ipmicfg
    lm_sensors
    #nvi
    vim
    pciutils
    screen
    smartmontools
    usbutils
    iotop

    # debug stuff
    config.boot.kernelPackages.bcc
    # dstat # broken..
    strace

    glibc
    ipset
    ncurses

    wireguard
    wireguard-tools
  ];

  # to be able to include ipmicfg
  nixpkgs.config.allowUnfree = true;

  networking.openDNS = false;
  environment.etc."resolv.conf".text = ''
    domain vpsfree.cz
    search vpsfree.cz prg.vpsfree.cz base48.cz
    nameserver 172.18.2.10
    nameserver 172.18.2.11
  '';

  services.nfs.server.enable = true;
  services.node_exporter.enable = true;
  services.rsyslogd.forward = [ "172.17.1.78:11514" ];

  vpsadmin.enable = true;
  system.secretsDir = toString ../static/secrets;

  programs.bash.promptInit = ''
    # Provide a nice prompt if the terminal supports it.
    if [ "$TERM" != "dumb" -o -n "$INSIDE_EMACS" ]; then
      PROMPT_COLOR="1;31m"
      let $UID && PROMPT_COLOR="1;32m"
      PS1="\n\[\033[$PROMPT_COLOR\][\u@\H:\w]\\$\[\033[0m\] "
      if test "$TERM" = "xterm"; then
        PS1="\[\033]2;\h:\u:\w\007\]$PS1"
      fi
    fi
  '';
}
