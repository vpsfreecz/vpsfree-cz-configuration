{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.webui-dev" = rec {
    spin = "nixos";
    swpins.channels = [
      "nixos-stable"
      "os-staging"
      "vpsadmin"
    ];
    container.id = 20465;
    host = {
      name = "webui-dev";
      location = "int";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.9.138";
          prefix = 32;
        }
      ];
    };
    services.node-exporter = { };
    tags = [
      "vpsadmin"
      "webui"
      "auto-update"
    ];
    healthChecks = import ../../../../health-checks/vpsadmin/webui.nix;
  };
}
