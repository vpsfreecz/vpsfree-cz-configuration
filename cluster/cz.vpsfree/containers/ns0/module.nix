{ config, pkgs, ... }:
{
  cluster."cz.vpsfree/containers/ns0" = {
    spin = "nixos";
    pins.channels = [
      "nixos-stable"
      "os-staging"
      "vpsadmin"
    ];
    container.id = 26143;
    host = {
      name = "ns0";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.9.200";
          prefix = 32;
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
      ns = "ns0.vpsfree.cz";
    };
  };
}
