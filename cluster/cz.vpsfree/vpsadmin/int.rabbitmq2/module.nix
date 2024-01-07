{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.rabbitmq2" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "vpsadmin" ];
    container.id = 24800;
    host = { name = "rabbitmq2"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.176"; prefix = 32; } ];
    };
    services = {
      node-exporter = {};
      rabbitmq-exporter = {};
    };
    tags = [ "vpsadmin" "rabbitmq" "auto-update" ];
    healthChecks = import ../../../../health-checks/vpsadmin/rabbitmq.nix { inherit host; };
  };
}
