{ config, ... }:
{
  cluster."org.vpsadminos".global."int.iso" = rec {
    type = "container";
    spin = "nixos";
    container.id = 14562;
    addresses.primary = { address = "172.16.4.16"; prefix = 32; };
    services = {
      nginx = {};
      node-exporter = {};
    };
  };
}
