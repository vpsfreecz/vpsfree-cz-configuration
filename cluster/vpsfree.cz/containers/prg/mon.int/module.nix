{ config, ... }:
{
  cluster."vpsfree.cz".prg."mon.int" = rec {
    addresses.main = "172.16.4.10";
    services.node-exporter = {};
  };
}
