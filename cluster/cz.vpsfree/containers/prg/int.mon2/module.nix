{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.mon2" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-master" ];
    container.id = 19501;
    host = { name = "mon2"; location = "int.prg"; domain = "vpsfree.cz"; };
    addresses.primary = { address = "172.16.4.18"; prefix = 32; };
    services = {
      node-exporter = {};
      prometheus = {};
    };
    monitoring.isMonitor = true;
    tags = [ "monitor" ];
  };
}
