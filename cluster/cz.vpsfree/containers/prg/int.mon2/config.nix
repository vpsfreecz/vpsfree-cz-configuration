{ pkgs, lib, config, confLib, confData, ... }:
let
  mon1Name = "cz.vpsfree/containers/prg/int.mon1";

  mon1Meta = confLib.findMetaConfig {
    cluster = config.cluster;
    name = mon1Name;
  };

  mon1Data = confData.vpsadmin.containers.${mon1Meta.host.fqdn};

  allMachines = confLib.getClusterMachines config.cluster;

  mon1Node = lib.findFirst (m: m.metaConfig.host.fqdn == mon1Data.node.fqdn) null allMachines;

  mon1NodeCheck =
    if isNull mon1Node then
      abort "Node ${mon1Data.node.fqdn} of ${mon1Name} not found in cluster"
    else
      mon1Node.name;
in {
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
    ../../../../../configs/internal-dns
  ];

  clusterconf.monitor = {
    enable = true;
    retention.time = "30d";
    retention.size = "10GB";
    alerters = [
      "cz.vpsfree/containers/prg/int.alerts1"
      "cz.vpsfree/containers/prg/int.alerts2"
    ];
    externalUrl = "https://mon2.prg.vpsfree.cz/";
    allowedMachines = [
      "cz.vpsfree/containers/prg/proxy"
      "cz.vpsfree/containers/prg/int.grafana"
    ];
    monitorMachines = [
      mon1NodeCheck
      mon1Name
    ];
  };

  networking.nameservers = lib.mkForce [ "127.0.0.1" ];

  system.stateVersion = "22.05";
}
