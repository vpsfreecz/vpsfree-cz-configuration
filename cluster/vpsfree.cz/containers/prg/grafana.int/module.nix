{ config, ... }:
{
  cluster."vpsfree.cz".prg."grafana.int" = rec {
    type = "container";
    spin = "nixos";
    addresses.primary = "172.16.4.12";
    services = {
      grafana = {};
      node-exporter = {};
    };
  };
}
