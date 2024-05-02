{ config, pkgs, lib, confMachine, confLib, confData, ... }:
let
  inherit (lib) filter;

  monitors =
    filter
      (m: m.metaConfig.monitoring.isMonitor)
      (confLib.getClusterMachines config.cluster);

  api1 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.api1";
  };

  api2 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.api2";
  };

  vpsadmin1 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.vpsadmin1";
  };
in {
  vpsadmin.rabbitmq = {
    enable = true;

    allowedIPv4Ranges = {
      cluster = [
        "172.16.9.175/32"
        "172.16.9.176/32"
        "172.16.9.177/32"
      ];

      clients = [
        "${api1.addresses.primary.address}/32"
        "${api2.addresses.primary.address}/32"
        "${vpsadmin1.addresses.primary.address}/32"
      ] ++ (map (n: "${n.address}/${toString n.prefix}") confData.vpsadmin.networks.management.ipv4);

      management = [
        "172.16.107.0/24"
      ];

      monitoring = map (m: "${m.metaConfig.addresses.primary.address}/32") monitors;
    };
  };

  networking.hosts = {
    "172.16.9.175" = [ "rabbitmq1" ];
    "172.16.9.176" = [ "rabbitmq2" ];
    "172.16.9.177" = [ "rabbitmq3" ];
  };
}
