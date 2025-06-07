{ pkgs, lib, config, confLib, confData, ... }:
{
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
    ../../../../../configs/internal-dns
  ];

  clusterconf.monitor = {
    enable = true;
    retention.time = "30d";
    retention.size = "60GB";
    alerters = [
      "cz.vpsfree/containers/prg/int.alerts1"
      "cz.vpsfree/containers/prg/int.alerts2"
    ];
    externalUrl = "https://mon2.prg.vpsfree.cz/";
    allowedMachines = [
      "cz.vpsfree/containers/prg/proxy"
      "cz.vpsfree/containers/prg/int.grafana"
    ];
  };

  networking.nameservers = lib.mkForce [ "127.0.0.1" ];

  system.stateVersion = "22.05";
}
