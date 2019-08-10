{ config, ... }:
{
  cluster."vpsfree.cz".global.log = rec {
    addresses.main = "172.16.4.1";
    services.node-exporter = {};
  };
}
