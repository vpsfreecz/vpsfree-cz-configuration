{
  config,
  lib,
  pkgs,
  confData,
  confMachine,
  ...
}:
with lib;
let
  mkZoneFile =
    file:
    pkgs.replaceVars file {
      fqdn = confMachine.host.fqdn;
    };

  formatNetworks = list: map (net: "${net.address}/${toString net.prefix}") list;

  containerNetworks = formatNetworks confData.vpsadmin.networks.containers.ipv4;

  managementNetworks = formatNetworks confData.vpsadmin.networks.management.ipv4;

  allNetworks = containerNetworks ++ managementNetworks;
in
{
  services.bind = {
    enable = true;
    forwarders = [
      "37.205.9.100"
      "37.205.10.88"
    ];
    cacheNetworks = [
      "127.0.0.0/24"
      "172.16.0.0/12"
    ]
    ++ allNetworks;
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
    iptables -A nixos-fw -p udp -s 172.16.0.0/12 --dport 53 -j nixos-fw-accept
    iptables -A nixos-fw -p tcp -s 172.16.0.0/12 --dport 53 -j nixos-fw-accept
  ''
  + (concatMapStringsSep "\n" (net: ''
    iptables -A nixos-fw -p udp -s ${net} --dport 53 -j nixos-fw-accept
    iptables -A nixos-fw -p tcp -s ${net} --dport 53 -j nixos-fw-accept
  '') allNetworks);
}
