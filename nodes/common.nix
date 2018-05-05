{ config, lib, pkgs, ...}:
{
  networking.dhcp = true;
  networking.bird.enable = true;

  # XXX: include devel keys for now
  users.users.root.openssh.authorizedKeys.keys = with import ../ssh-keys.nix; [ aither snajpa snajpa_devel srk srk_devel ];

  boot.kernelModules = [ "ipmi_si" "ipmi_devintf" ];

  vpsadminos.nix = true;
  environment.systemPackages = with pkgs; [
    dmidecode
    ipmicfg
    lm_sensors
    nvi
    pciutils
    screen
    smartmontools
    usbutils

    # debug stuff
    config.boot.kernelPackages.bcc
    dstat
    strace
  ];

  # to be able to include ipmicfg
  nixpkgs.config.allowUnfree = true;

  networking.openDNS = false;
  environment.etc."resolv.conf.tail".text = ''
    domain vpsfree.cz
    search vpsfree.cz prg.vpsfree.cz base48.cz
    nameserver 172.17.4.11
  '';

  services.nfs.server.enable = true;
}
