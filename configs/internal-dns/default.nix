{ config, lib, pkgs, confMachine, ... }:
let
  mkZoneFile = file: pkgs.substituteAll {
    src = file;
    fqdn = confMachine.host.fqdn;
  };
in {
  services.bind = {
    enable = true;
    forwarders = [
      "37.205.9.100"
      "37.205.10.88"
    ];
    cacheNetworks = [
      "127.0.0.0/24"
      "172.16.0.0/12"
    ];
    zones = [
      {
        name = "vpsfree.cz.";
        master = true;
        file = mkZoneFile ./zone.vpsfree.cz.;
      }
      {
        name = "vpsadminos.org.";
        master = true;
        file = mkZoneFile ./zone.vpsadminos.org.;
      }
    ];
  };

  networking.firewall.extraCommands = ''
    iptables -A INPUT -p udp -m udp -s 172.16.0.0/12 --dport 53 -j ACCEPT
  '';
}
