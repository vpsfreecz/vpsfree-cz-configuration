{ config, ... }:
{
  cluster."cz.vpsfree/containers/int.vpsfbot" = {
    spin = "nixos";
    swpins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 21296;
    host = {
      name = "vpsfbot";
      location = "int";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.4.8";
          prefix = 32;
        }
      ];
    };
    services = {
      node-exporter = { };
    };
    tags = [ "auto-update" ];

    healthChecks = {
      systemd.unitProperties = {
        "vpsfree-irc-bot-libera.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];
      };
    };
  };
}
