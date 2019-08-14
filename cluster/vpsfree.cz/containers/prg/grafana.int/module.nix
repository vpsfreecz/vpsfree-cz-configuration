{ config, ... }:
{
  cluster."vpsfree.cz".prg."grafana.int" = rec {
    type = "container";
    spin = "nixos";
    container.id = 14118;
    addresses.primary = { address = "172.16.4.12"; prefix = 32; };
    services = {
      grafana = {};
      node-exporter = {};
    };
  };
}
