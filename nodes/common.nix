{ config, lib, pkgs, ...}:
{

  imports = [
    ./bird.nix
    ../modules/havesnippet.nix
  ];
  users.users.root.openssh.authorizedKeys.keys = with import ../ssh-keys.nix; [ aither snajpa srk ];
  users.users.root.initialHashedPassword = "$6$bdENLP5gkTO$iVMOmBo4EmmP2YawSOHEvMlq1WDn9RvMCG3ChYfpBoYKejAIz/g78EP2gfE8zM2SdS8p3O8E2LbzQMXwOupdj/";

  boot.kernelModules = [
    "ipmi_si"
    "ipmi_devintf"
  ];

  boot.extraModulePackages = [ config.boot.kernelPackages.wireguard ];
  boot.kernel.sysctl = {
    "vm.overcommit_ratio" = 3200;
    "fs.aio-max-nr" = 200000;
    "net.ipv4.neigh.default.gc_thresh1" = 2048;
    "net.ipv4.neigh.default.gc_thresh2" = 4096;
    "net.ipv4.neigh.default.gc_thresh3" = 8192;
  };

  boot.extraModprobeConfig = "options zfs zfs_arc_min=34359738368";

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
    # config.boot.kernelPackages.bcc
    config.boot.kernelPackages.bpftrace
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
  
  nixpkgs.overlays = import ../overlays;

  networking.openDNS = false;
  environment.etc."resolv.conf".text = ''
    domain vpsfree.cz
    search vpsfree.cz prg.vpsfree.cz base48.cz
    nameserver 172.18.2.10
    nameserver 172.18.2.11
  '';

  services.nfs.server.enable = true;
  services.node_exporter.enable = true;
  services.rsyslogd.forward = [ "172.17.1.245:11514" ];

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

  programs.havesnippet.enable = true;

  services.haveged.enable = true;

  osctl.pools.tank = {
    parallelStart = 2;
    parallelStop = 4;
  };
}
