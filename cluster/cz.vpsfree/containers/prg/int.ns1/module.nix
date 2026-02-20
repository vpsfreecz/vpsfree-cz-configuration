{ config, pkgs, ... }:
let
  addr = "172.16.9.90";
in
{
  cluster."cz.vpsfree/containers/prg/int.ns1" = rec {
    spin = "nixos";
    pins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 21850;
    host = {
      name = "ns1";
      location = "int.prg";
      domain = "vpsfree.cz";
      target = addr;
    };
    addresses = {
      v4 = [
        {
          address = addr;
          prefix = 32;
        }
      ];
    };
    services = {
      bind = { };
      node-exporter = { };
    };
    tags = [
      "dns"
      "internal-dns"
      "all-internal-dns"
      "manual-update"
    ];
    healthChecks = import ../../../../../health-checks/internal-dns.nix { inherit pkgs addr; };
  };
}
