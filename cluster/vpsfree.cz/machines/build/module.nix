{ config, ... }:
{
  cluster."vpsfree.cz".global.build = rec {
    addresses.primary = "172.16.254.4";
    services.node-exporter = {};
  };
}
