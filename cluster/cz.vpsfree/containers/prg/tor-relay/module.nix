{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/tor-relay" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 18115;
    host = { name = "tor-relay"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "37.205.8.191"; prefix = 32; } ];
    };
    services = {
      node-exporter = {};
    };
  };
}
