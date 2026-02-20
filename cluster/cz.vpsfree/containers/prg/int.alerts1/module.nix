{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.alerts1" = rec {
    spin = "nixos";
    pins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 14077;
    host = {
      name = "alerts1";
      location = "int.prg";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.4.11";
          prefix = 32;
        }
      ];
    };
    services = {
      alertmanager = { };
      node-exporter = { };
    };
    tags = [
      "alerter"
      "auto-update"
    ];
    healthChecks = import ../../../../../health-checks/alerts.nix;
  };
}
