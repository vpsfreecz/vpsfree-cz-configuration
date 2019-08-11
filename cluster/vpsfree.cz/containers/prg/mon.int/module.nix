{ config, ... }:
{
  cluster."vpsfree.cz".prg."mon.int" = rec {
    addresses.primary = "172.16.4.10";
    services = {
      node-exporter = {};
      prometheus = {};
    };
  };
}
