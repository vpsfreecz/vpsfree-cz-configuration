{ config, ... }:
{
  cluster."org.vpsadminos/containers/int.cache" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-master" ];
    container.id = 14573;
    host = { name = "cache"; domain = "int.vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.30"; prefix = 32; };
    services = {
      nix-serve = {};
      node-exporter = {};
    };
  };
}
