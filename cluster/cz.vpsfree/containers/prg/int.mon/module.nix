{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.mon" = rec {
    spin = "nixos";
    container.id = 14005;
    host = { name = "mon.int"; location = "prg"; domain = "vpsfree.cz"; };
    addresses.primary = { address = "172.16.4.10"; prefix = 32; };
    services = {
      node-exporter = {};
      prometheus = {};
    };
    monitoring.isMonitor = true;
  };
}
