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

    tags = [ "manual-update" ];

    healthChecks = {
      systemd.unitProperties = {
        "nginx.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "mysql.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "phpfpm-wordpress-blog.vpsfree.cz.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "wordpress-init-blog.vpsfree.cz.service" = [
          {
            property = "Result";
            value = "success";
          }
          {
            property = "ExecMainStatus";
            value = "0";
          }
        ];
      };

      machineCommands = [
        {
          description = "Check blog.vpsfree.cz locally";
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
      ];
    };
  };
}
