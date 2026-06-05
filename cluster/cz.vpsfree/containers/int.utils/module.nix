{ config, ... }:
{
  cluster."cz.vpsfree/containers/int.utils" = {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 23188;
    host = {
      name = "utils";
      location = "int";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.9.156";
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

        "phpfpm-adminer.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];
      };

      machineCommands = [
        {
          description = "Check Adminer web";
          command = [
            "curl"
            "--fail"
            "--silent"
            "--show-error"
            "--location"
            "--max-time"
            "10"
            "--resolve"
            "utils.vpsfree.cz:80:127.0.0.1"
            "http://utils.vpsfree.cz/adminer/adminer.php"
          ];
          standardOutput.include = [
            "Adminer"
          ];
        }
      ];
    };
  };
}
