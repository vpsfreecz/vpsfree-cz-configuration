{ config, ... }:
{
  cluster."org.vpsadminos/containers/int.bb.nixos02" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "os-runtime-deps" ];
    container.id = 14575;
    host = { name = "nixos02"; domain = "bb.int.vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.22"; prefix = 32; };
    services.node-exporter = {};
    monitoring.enable = false;
  };
}
