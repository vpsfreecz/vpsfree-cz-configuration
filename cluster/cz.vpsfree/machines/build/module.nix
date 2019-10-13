{ config, ... }:
{
  cluster."cz.vpsfree".global.build = rec {
    type = "machine";
    spin = "vpsadminos";
    addresses.primary = { address = "172.16.254.4"; prefix = 32; };
    services.node-exporter = {};
  };
}
