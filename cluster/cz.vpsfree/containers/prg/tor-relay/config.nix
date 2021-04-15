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
  };
  services.tor.relay = {
    enable = true;
    role = "relay";
    nickname = "relay0vpsfree0cz";
    bandwidthRate = 26214400;
    bandwidthBurst = 34078720;
    port = 443;
    exitPolicy = "reject *:*";
    contactInfo = "martin.myska@vpsfree.cz";
  };
}
