{ config, ... }:
{
  cluster."cz.vpsfree/machines/build" = rec {
    spin = "vpsadminos";
    host = { name = "build"; domain = "vpsfree.cz"; };
    addresses.primary = { address = "172.16.254.4"; prefix = 32; };
    services.node-exporter = {};
  };
}
