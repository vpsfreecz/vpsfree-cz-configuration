{ config, pkgs, ... }:
let
  addr = "172.19.9.90";
in
{
  cluster."cz.vpsfree/containers/brq/int.ns1" = rec {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 21851;
    host = {
      name = "ns1";
      location = "int.brq";
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
