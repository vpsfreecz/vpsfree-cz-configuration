{ config, ... }:
{
  cluster."org.vpsadminos/containers/int.iso" = rec {
    spin = "nixos";
    container.id = 14562;
    host = { name = "iso.int"; domain = "vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.16"; prefix = 32; };
    services = {
      nginx = {};
      node-exporter = {};
    };
  };
}
