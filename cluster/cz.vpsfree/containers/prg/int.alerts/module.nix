{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.alerts" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-master" ];
    container.id = 14077;
    host = { name = "alerts"; location = "int.prg"; domain = "vpsfree.cz"; };
    addresses.primary = { address = "172.16.4.11"; prefix = 32; };
    services = {
      alertmanager = {};
      node-exporter = {};
    };
  };
}
