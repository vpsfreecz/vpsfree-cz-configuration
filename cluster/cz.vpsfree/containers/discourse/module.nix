{ config, ... }:
{
  cluster."cz.vpsfree/containers/discourse" = {
    spin = "nixos";
    swpins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 24920;
    host = {
      name = "discourse";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "37.205.13.116";
          prefix = 32;
        }
      ];
    };
    services = {
      node-exporter = { };
    };
    tags = [
      "discourse"
      "auto-update"
    ];

    healthChecks = {
      systemd.unitProperties = {
        "discourse.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "postfix.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "postgresql.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];
      };
    };
  };
}
