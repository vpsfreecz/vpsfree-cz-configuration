{ config, ... }:
{
  cluster."vpsfree.cz".global.build = rec {
    type = "machine";
    spin = "vpsadminos";
    addresses.primary = "172.16.254.4";
    services.node-exporter = {};
  };
}
