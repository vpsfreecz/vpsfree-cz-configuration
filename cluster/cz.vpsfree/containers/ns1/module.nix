{ config, pkgs, ... }:
{
  cluster."cz.vpsfree/containers/ns1" = {
    spin = "nixos";
    pins.channels = [
      "nixos-stable"
      "os-staging"
      "vpsadmin"
    ];
    container.id = 25113;
    host = {
      name = "ns1";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "37.205.9.232";
          prefix = 32;
        }
      ];
      v6 = [
        {
          address = "2a03:3b40:fe:3fd::1";
          prefix = 64;
        }
      ];
    };
    services = {
      bind = { };
      bind-exporter = { };
      node-exporter = { };
    };
    tags = [
      "dns"
      "public-dns"
      "vpsadmin"
      "auto-update"
    ];
    healthChecks = import ../../../../health-checks/public-dns.nix {
      inherit pkgs;
      ns = "ns1.vpsfree.cz";
    };
  };
}
