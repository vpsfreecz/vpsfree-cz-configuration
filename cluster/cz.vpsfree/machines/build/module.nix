{ config, ... }:
{
  cluster."cz.vpsfree/machines/build" = rec {
    spin = "vpsadminos";
    swpins.channels = [ "os-staging" "nixos-unstable" ];
    host = { name = "build"; domain = "vpsfree.cz"; };
    addresses.primary = { address = "172.16.254.4"; prefix = 32; };
    services.node-exporter = {};
  };
}
