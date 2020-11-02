{ config, ... }:
{
  cluster."org.vpsadminos/containers/int.www" = rec {
    spin = "nixos";
    container.id = 14563;
    host = { name = "www.int"; domain = "vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.17"; prefix = 32; };
    services = {
      nginx = {};
      node-exporter = {};
    };
  };
}
