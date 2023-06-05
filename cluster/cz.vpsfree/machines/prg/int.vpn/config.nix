{ config, pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ../../../../../environments/base.nix
    ../../../../../configs/wireguard
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  services.openssh.settings.PermitRootLogin = "yes";

  networking = {
    useDHCP = false;

    vlans = {
      vlan100 = { id=100; interface="enp2s0"; };
      vlan220 = { id=220; interface="enp2s0"; };
    };

    interfaces.vlan100 = {
      ipv4.addresses = [{
        address = "172.16.100.7";
        prefixLength = 24;
      }];
      ipv4.routes = [{
        address = "172.16.0.0";
        prefixLength = 12;
        via = "172.16.100.1";
      }];
      useDHCP = false;
    };

    interfaces.vlan220 = {
      ipv4.addresses = [{
        address = "77.93.223.7";
        prefixLength = 26;
      }];
      useDHCP = false;
    };

    defaultGateway = "77.93.223.1";
  };

  system.stateVersion = "22.05";
}
