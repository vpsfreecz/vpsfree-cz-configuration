{ config, ... }:
{
  cluster."cz.vpsfree/machines/build-old" = rec {
    spin = "vpsadminos";
    swpins.channels = [ "os-staging" "nixos-stable" ];
    host = { name = "build-old"; domain = "vpsfree.cz"; target = "172.16.254.4"; };
    addresses.primary = { address = "172.16.254.4"; prefix = 32; };
    monitoring.enable = false;
    services.node-exporter = {};
  };
}
