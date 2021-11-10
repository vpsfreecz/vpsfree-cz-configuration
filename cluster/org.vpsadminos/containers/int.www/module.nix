{ config, ... }:
{
  cluster."org.vpsadminos/containers/int.www" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "os-runtime-deps" ];
    container.id = 14563;
    host = { name = "www"; domain = "int.vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.17"; prefix = 32; };
    services = {
      nginx = {};
      node-exporter = {};
    };
  };
}
