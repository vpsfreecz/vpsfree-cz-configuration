{ config, ... }:
{
  cluster."cz.vpsfree/containers/int.kb" = {
    spin = "nixos";
    inputs.channels = [
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

    healthChecks = {
      systemd.unitProperties = {
        "nginx.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "phpfpm-dokuwiki-kb.vpsfree.cz.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "phpfpm-dokuwiki-kb.vpsfree.org.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];
      };

      machineCommands = [
        {
          description = "Check kb.vpsfree.cz";
          command = [
            "curl"
            "--fail"
            "--silent"
            "--show-error"
            "--location"
            "--max-time"
            "10"
            "--header"
            "Host: kb.vpsfree.cz"
            "http://localhost/"
          ];
          standardOutput.include = [
            "Znalostní báze"
          ];
        }
        {
          description = "Check kb.vpsfree.org";
          command = [
            "curl"
            "--fail"
            "--silent"
            "--show-error"
            "--location"
            "--max-time"
            "10"
            "--header"
            "Host: kb.vpsfree.org"
            "http://localhost/"
          ];
          standardOutput.include = [
            "Knowledge base"
          ];
        }
      ];
    };
  };
}
