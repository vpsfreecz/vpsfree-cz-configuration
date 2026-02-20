{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.vpsadmin1" = rec {
    spin = "nixos";
    pins.channels = [
      "nixos-stable"
      "os-staging"
      "vpsadmin"
    ];
    container.id = 21989;
    host = {
      name = "vpsadmin1";
      location = "int";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.9.145";
          prefix = 32;
        }
      ];
    };
    services.node-exporter = { };
    tags = [
      "vpsadmin"
      "mailer"
      "auto-update"
    ];

    healthChecks = {
      systemd.unitProperties = {
        "vpsadmin-nodectld.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];
      };
    };
  };
}
