{ config, pkgs, lib, confDir, confLib, confData, confMachine, ... }:
let
  images = import ../../../../../lib/images.nix {
    inherit config lib pkgs confDir confLib confData confMachine;
    nixosModules = [
      ../../../../../environments/base.nix
    ];
  };
in {
  imports = [
    ./hardware.nix
    ../../common/all.nix
    ../../common/apu.nix
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{serial}=="AK05VT13", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-brq-1-12-mgmt-sg300"
    SUBSYSTEM=="tty", ATTRS{serial}=="001704B5", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-brq-1-12-tor1-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="001704A7", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-brq-1-12-tor2-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="00131468", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-brq-1-12-edg1-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="00170075", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-brq-1-12-edg2-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="AC025AG5", OWNER="snajpa", GROUP="snajpa",       SYMLINK+="ttyUSB-q66"
  '';

  networking.interfaces.enp1s0.useDHCP = false;
  networking.interfaces.enp1s0.ipv4.addresses = [
    { address = "172.19.254.254"; prefixLength = 24; }
    { address = "172.19.254.253"; prefixLength = 24; }
  ];
  networking.interfaces.enp1s0.ipv4.routes = [
    { address = "172.16.0.0"; prefixLength = 12; via = "172.19.254.1"; }
  ];

  services.netboot = {
    enable = true;
    host = "172.19.254.253";
    tftp.bindAddress = "172.19.254.253";
    inherit (images) nixosItems;
    vpsadminosItems = images.allNodes "vpsfree.cz";
    allowedIPRanges = [
      "172.16.254.0/24"
      "172.19.254.0/24"
    ];
  };

  system.stateVersion = "21.11";
}
