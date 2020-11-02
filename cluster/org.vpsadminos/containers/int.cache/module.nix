{ config, ... }:
{
  cluster."org.vpsadminos/containers/int.cache" = rec {
    spin = "nixos";
    container.id = 14573;
    host = { name = "cache.int"; domain = "vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.30"; prefix = 32; };
    services = {
      nix-serve = {};
      node-exporter = {};
    };
  };
}
