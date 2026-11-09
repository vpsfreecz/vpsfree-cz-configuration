{ ... }:
{
  cluster."cz.vpsfree/containers/int.blog" = {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
    ];

    container.id = 29942;

    host = {
      name = "blog";
      location = "int";
      domain = "vpsfree.cz";
      target = "172.16.8.4";
    };

    addresses.v4 = [
      {
        address = "172.16.8.4";
        prefix = 32;
      }
    ];

    monitoring = {
      enable = false;
      target = "172.16.8.4";
    };
    logging.enable = false;

    services.node-exporter = { };

    tags = [ "auto-update" ];

    healthChecks = {
      systemd.unitProperties = {
        "nginx.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

      };

      machineCommands = [
        {
          description = "Check the selected Czech blog frontend locally";
          command = [
            "curl"
            "--fail"
            "--silent"
            "--show-error"
            "--max-time"
            "10"
            "--output"
            "/dev/null"
            "--header"
            "Host: blog.vpsfree.cz"
            "--header"
            "X-Forwarded-Proto: https"
            "http://localhost/"
          ];
          standardOutput.match = "";
        }
        {
          description = "Check the selected English blog frontend locally";
          command = [
            "curl"
            "--fail"
            "--silent"
            "--show-error"
            "--max-time"
            "10"
            "--output"
            "/dev/null"
            "--header"
            "Host: blog.vpsfree.org"
            "--header"
            "X-Forwarded-Proto: https"
            "http://localhost/"
          ];
          standardOutput.match = "";
        }
      ];
    };
  };
}
