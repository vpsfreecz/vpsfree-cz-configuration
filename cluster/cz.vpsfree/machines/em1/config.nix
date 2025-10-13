{ config, lib, ... }:
{
  imports = [
    ./hardware.nix
    ../common/all.nix
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = false;
    devices = [ "/dev/sda" ];
  };

  networking.interfaces.enp1s0.useDHCP = true;

  networking.interfaces.enp1s0.ipv6.addresses = [
    {
      address = "2a01:4f8:1c1a:7604::1";
      prefixLength = 64;
    }
  ];

  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "enp1s0";
  };

  networking.nameservers = lib.mkForce [ ];

  system.stateVersion = "25.05";
}
