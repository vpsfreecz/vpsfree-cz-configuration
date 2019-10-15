{ config, ... }:
{
  cluster."org.vpsadminos".global."int.www" = rec {
    type = "container";
    spin = "nixos";
    container.id = 14563;
    addresses.primary = { address = "172.16.4.17"; prefix = 32; };
    services = {
      nginx = {};
      node-exporter = {};
    };
  };
}
