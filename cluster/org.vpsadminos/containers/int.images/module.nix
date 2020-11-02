{ config, ... }:
{
  cluster."org.vpsadminos/containers/int.images" = rec {
    spin = "nixos";
    container.id = 14561;
    host = { name = "images.int"; domain = "vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.15"; prefix = 32; };
    services = {
      nginx = {};
      node-exporter = {};
    };
  };
}
