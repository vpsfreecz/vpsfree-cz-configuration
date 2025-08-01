{ config, ... }:
{
  cluster."cz.vpsfree/containers/int.web" = {
    spin = "nixos";
    swpins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 22523;
    host = {
      name = "web";
      location = "int";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.9.28";
          prefix = 32;
        }
      ];
    };
    services = {
      node-exporter = { };
    };
    tags = [ "auto-update" ];
  };
}
