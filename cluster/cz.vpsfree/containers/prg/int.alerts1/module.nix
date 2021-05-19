{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.alerts1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-master" ];
    container.id = 14077;
    host = { name = "alerts1"; location = "int.prg"; domain = "vpsfree.cz"; };
    addresses.primary = { address = "172.16.4.11"; prefix = 32; };
    services = {
      alertmanager = {};
      node-exporter = {};
    };
    tags = [ "alerter" ];
  };
}
