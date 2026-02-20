{ config, ... }:
{
  cluster."cz.vpsfree/containers/int.kb" = {
    spin = "nixos";
    pins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 24965;
    host = {
      name = "kb";
      location = "int";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.9.179";
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
