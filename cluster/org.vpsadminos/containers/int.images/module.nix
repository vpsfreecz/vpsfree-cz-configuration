{ config, ... }:
{
  cluster."org.vpsadminos".global."int.images" = rec {
    type = "container";
    spin = "nixos";
    container.id = 14561;
    addresses.primary = { address = "172.16.4.15"; prefix = 32; };
    services = {
      nginx = {};
      node-exporter = {};
    };
  };
}
