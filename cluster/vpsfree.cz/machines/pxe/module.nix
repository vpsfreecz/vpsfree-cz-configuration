{ config, ... }:
{
  cluster."vpsfree.cz".global.pxe = rec {
    addresses.main = "172.16.254.5";
    services.node-exporter = {};
  };
}
