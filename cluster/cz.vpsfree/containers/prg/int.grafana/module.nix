{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.grafana" = rec {
    spin = "nixos";
    container.id = 14118;
    host = { name = "grafana.int"; location = "prg"; domain = "vpsfree.cz"; };
    addresses.primary = { address = "172.16.4.12"; prefix = 32; };
    services = {
      grafana = {};
      node-exporter = {};
    };
  };
}
