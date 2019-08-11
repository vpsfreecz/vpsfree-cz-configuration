{ config, ... }:
{
  cluster."vpsfree.cz".prg."alerts.int" = rec {
    addresses.primary = "172.16.4.11";
    services = {
      alertmanager = {};
      node-exporter = {};
    };
  };
}
