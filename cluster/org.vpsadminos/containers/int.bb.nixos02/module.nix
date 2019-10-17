{ config, ... }:
{
  cluster."org.vpsadminos".global."int.bb.nixos02" = rec {
    type = "container";
    spin = "nixos";
    container.id = 14575;
    addresses.primary = { address = "172.16.4.22"; prefix = 32; };
    services.node-exporter = {};
  };
}
