{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.grafana" = rec {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 14118;
    host = {
      name = "grafana";
      location = "int.prg";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.4.12";
          prefix = 32;
        }
      ];
    };
    services = {
      grafana = { };
      node-exporter = { };
    };
    tags = [ "auto-update" ];

    healthChecks = {
      systemd.unitProperties = {
        "grafana.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];
      };

      machineCommands = [
        {
          description = "Check Grafana health endpoint";
          command = [
            "curl"
            "--fail"
            "--silent"
            "--show-error"
            "--max-time"
            "10"
            "http://localhost:3000/api/health"
          ];
          standardOutput.include = [
            "database"
            "ok"
          ];
        }
      ];
    };
  };
}
