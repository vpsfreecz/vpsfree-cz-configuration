{ config, ... }:
{
  cluster."cz.vpsfree/containers/int.web" = {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
      "vpsfree-web"
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

    healthChecks = {
      systemd.unitProperties = {
        "nginx.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "phpfpm-vpsfree.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];
      };

      machineCommands = [
        {
          description = "Check vpsfree.cz web";
          command = [
            "curl"
            "--fail"
            "--silent"
            "--show-error"
            "--location"
            "--max-time"
            "10"
            "--header"
            "Host: vpsfree.cz"
            "http://localhost/"
          ];
          standardOutput.include = [
            "milujeme servery"
          ];
        }
        {
          description = "Check vpsfree.org web";
          command = [
            "curl"
            "--fail"
            "--silent"
            "--show-error"
            "--location"
            "--max-time"
            "10"
            "--header"
            "Host: vpsfree.org"
            "http://localhost/"
          ];
          standardOutput.include = [
            "we love servers"
          ];
        }
      ];
    };
  };
}
