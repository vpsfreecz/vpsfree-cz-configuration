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
            "--resolve"
            "vpsfree.cz:80:127.0.0.1"
            "http://vpsfree.cz/"
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
            "--resolve"
            "vpsfree.org:80:127.0.0.1"
            "http://vpsfree.org/"
          ];
          standardOutput.include = [
            "we love servers"
          ];
        }
      ];
    };
  };
}
