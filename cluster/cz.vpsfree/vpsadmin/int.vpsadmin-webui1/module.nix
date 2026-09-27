{ ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.vpsadmin-webui1" = {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
      "vpsadmin-webui"
    ];
    container.id = 30431;
    host = {
      name = "vpsadmin-webui1";
      location = "int";
      domain = "vpsfree.cz";
    };
    addresses.v4 = [
      {
        address = "172.16.9.170";
        prefix = 32;
      }
    ];
    services.node-exporter = { };
    tags = [
      "vpsadmin"
      "webui"
      "manual-update"
    ];
    healthChecks = import ../../../../health-checks/vpsadmin-webui.nix;
  };
}
