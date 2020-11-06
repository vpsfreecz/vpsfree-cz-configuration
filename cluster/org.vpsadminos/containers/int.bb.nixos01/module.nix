{ config, ... }:
{
  cluster."org.vpsadminos/containers/int.bb.nixos01" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-master" "os-runtime-deps" ];
    container.id = 14571;
    host = { name = "nixos01.bb.int"; domain = "vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.21"; prefix = 32; };
    services.node-exporter = {};
    monitoring.enable = false;
  };
}
