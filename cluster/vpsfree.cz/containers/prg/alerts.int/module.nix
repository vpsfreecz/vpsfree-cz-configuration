{ config, ... }:
{
  cluster."vpsfree.cz".prg."alerts.int" = rec {
    addresses.main = "172.16.4.11";
    services.node-exporter = {};
  };
}
