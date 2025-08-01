{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.rabbitmq1" = rec {
    spin = "nixos";
    swpins.channels = [
      "nixos-stable"
      "os-staging"
      "vpsadmin"
    ];
    container.id = 24799;
    host = {
      name = "rabbitmq1";
      location = "int";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.9.175";
          prefix = 32;
        }
      ];
    };
    services = {
      node-exporter = { };
      rabbitmq-exporter = { };
    };
    tags = [
      "vpsadmin"
      "rabbitmq"
      "auto-update"
    ];
    healthChecks = import ../../../../health-checks/vpsadmin/rabbitmq.nix { inherit host; };
  };
}
