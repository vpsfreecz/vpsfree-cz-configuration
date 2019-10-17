{ config, ... }:
{
  cluster."org.vpsadminos".global."int.cache" = rec {
    type = "container";
    spin = "nixos";
    container.id = 14573;
    addresses.primary = { address = "172.16.4.30"; prefix = 32; };
    services = {
      nix-serve = {};
      node-exporter = {};
    };
  };
}
