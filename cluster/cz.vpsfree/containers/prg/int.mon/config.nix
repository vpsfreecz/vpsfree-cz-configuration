{ pkgs, lib, config, ... }:
{
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
  ];

  clusterconf.monitor = {
    enable = true;
    retention.time = "365d";
    retention.size = "200GB";
    alerters = [
      "cz.vpsfree/containers/prg/int.alerts"
    ];
    externalUrl = "https://mon.prg.vpsfree.cz/";
    allowedMachines = [
      "cz.vpsfree/containers/prg/proxy"
      "cz.vpsfree/containers/prg/int.grafana"
    ];
  };
}
