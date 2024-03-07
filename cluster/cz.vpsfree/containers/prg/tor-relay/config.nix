{ pkgs, lib, confLib, config, confMachine, ... }:
{
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
  ];

  networking.firewall.allowedTCPPorts = [ 443 ];
  networking.firewall.allowedUDPPorts = [ 443 ];

  services.tor = {
    enable = true;
    #controlPort = 9051;
    relay = {
      enable = true;
      role = "relay";
    };
    settings = {
      Nickname = "relay0vpsfree0cz";
      BandwidthRate = 26214400;
      BandwidthBurst = 34078720;
      ORPort = 443;
      ExitPolicy = "reject *:*";
      ContactInfo = "support@vpsfree.org";
    };
  };

  system.stateVersion = "22.05";
}
