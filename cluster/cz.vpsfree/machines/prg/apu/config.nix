{ config, ... }:
{
  imports = [
    ./hardware.nix
    ../../common/all.nix
    ../../common/apu.nix
    ../../../../../configs/carrier.nix
    ../../../../../configs/vpsf-status.nix
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{serial}=="0001B337", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-prg-4-7-edg1-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="001333D5", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-prg-4-7-tor1-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="00013C0F", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-prg-4-7-tor2-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="000C5978", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-prg-14-7-edg2-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="000CBF24", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-prg-14-7-tor1-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="000BF9F8", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-prg-14-7-tor2-s4048"
    SUBSYSTEM=="tty", ATTRS{serial}=="001333B4", OWNER="snajpa", GROUP="tty-vpsf-net", SYMLINK+="ttyUSB-dev-s4048"
  '';

  networking.interfaces.enp1s0.useDHCP = false;
  networking.interfaces.enp1s0.ipv4.addresses = [
    {
      address = "172.16.254.254";
      prefixLength = 24;
    }
    {
      address = "172.16.254.253";
      prefixLength = 24;
    }
  ];
  networking.interfaces.enp1s0.ipv4.routes = [
    {
      address = "172.16.0.0";
      prefixLength = 12;
      via = "172.16.254.1";
    }
  ];

  networking.wireguard.interfaces.wg0.ips = [ "172.31.0.33/30" ];

  confctl.carrier.netboot = {
    host = "172.16.254.253";
    tftp.bindAddress = "172.16.254.253";
  };

  system.stateVersion = "21.11";
}
