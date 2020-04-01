{ config, ... }:
{
  cluster."org.vpsadminos".global."int.bb.nixos01" = rec {
    type = "container";
    spin = "nixos";
    container.id = 14571;
    addresses.primary = { address = "172.16.4.21"; prefix = 32; };
    services.node-exporter = {};
    monitoring.enable = false;
  };
}
