{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.api2" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "vpsadmin" ];
    container.id = 20274;
    host = { name = "api2"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.129"; prefix = 32; } ];
    };
    services.node-exporter = {};
    tags = [ "vpsadmin" "api" "auto-update" ];
    healthChecks = import ../../../../health-checks/vpsadmin/api.nix;
  };
}
