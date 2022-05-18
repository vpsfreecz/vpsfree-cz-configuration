{ config, pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ../../common/apu.nix
    ../../../../../environments/base.nix
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{serial}=="AK05VT13", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-brq-1-12-mgmt-sg300"
    SUBSYSTEM=="tty", ATTRS{serial}=="001704B5", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-brq-1-12-tor1-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="001704A7", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-brq-1-12-tor2-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="00131468", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-brq-1-12-edg1-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="00170075", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-brq-1-12-edg2-s4048"
  '';

  networking.interfaces.enp1s0.useDHCP = false;
  networking.interfaces.enp1s0.ipv4.addresses = [
    { address = "172.19.254.254"; prefixLength = 24; }
  ];
  networking.interfaces.enp1s0.ipv4.routes = [
    { address = "172.16.0.0"; prefixLength = 12; via = "172.19.254.1"; }
  ];

  system.stateVersion = "21.11";
}
