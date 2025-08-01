{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
  ];

  clusterconf.alerter = {
    enable = true;
    externalUrl = "https://alerts.prg.vpsfree.cz/";
    allowedMachines = [
      "cz.vpsfree/containers/prg/proxy"
      "cz.vpsfree/containers/prg/int.log"
    ];
    clusterPeers = [
      "cz.vpsfree/containers/prg/int.alerts1"
      "cz.vpsfree/containers/prg/int.alerts2"
    ];
  };

  system.stateVersion = "22.05";
}
