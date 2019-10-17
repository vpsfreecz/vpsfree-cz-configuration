{ config, ... }:
{
  cluster."org.vpsadminos".global."int.bb.master" = rec {
    type = "container";
    spin = "nixos";
    container.id = 14570;
    addresses.primary = { address = "172.16.4.20"; prefix = 32; };
    services.node-exporter = {};
  };
}
