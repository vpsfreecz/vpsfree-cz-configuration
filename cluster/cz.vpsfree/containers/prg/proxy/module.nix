{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/proxy" = rec {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
      "vpsadmin"
    ];
    container.id = 14096;
    host = {
      name = "proxy";
      location = "prg";
      domain = "vpsfree.cz";
    };
    addresses = {
      v4 = [
        {
          address = "172.16.9.140";
          prefix = 32;
        }
      ];
    };
    services = {
      haproxy-exporter = { };
      node-exporter = { };
      varnish-exporter = { };
    };
    tags = [
      "monitor"
      "vpsadmin"
      "manual-update"
    ];

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
          description = "Check proxied vpsfree.cz over HTTPS";
          command = [
            "curl"
            "--fail"
            "--silent"
            "--show-error"
            "--location"
            "--max-time"
            "10"
            "--resolve"
            "vpsfree.cz:443:127.0.0.1"
            "https://vpsfree.cz/"
          ];
          standardOutput.include = [
            "milujeme servery"
          ];
        }
        {
          description = "Check proxied kb.vpsfree.cz over HTTPS";
          command = [
            "curl"
            "--fail"
            "--silent"
            "--show-error"
            "--location"
            "--max-time"
            "10"
            "--resolve"
            "kb.vpsfree.cz:443:127.0.0.1"
            "https://kb.vpsfree.cz/"
          ];
          standardOutput.include = [
            "Znalostní báze"
          ];
        }
        {
          description = "Check newadmin frontend over local HTTPS";
          command = [
            "bash"
            "-euo"
            "pipefail"
            "-c"
            ''curl --fail --silent --show-error --max-time 10 --resolve newadmin.vpsfree.cz:443:127.0.0.1 https://newadmin.vpsfree.cz/build-info.json | jq -e '.schemaVersion == 1 and (.commit | type == "string" and length == 40 and test("^[0-9a-f]+$")) and (.dirty | type == "boolean")' >/dev/null''
          ];
        }
        {
          description = "Check newadmin BFF over local HTTPS";
          command = [
            "bash"
            "-euo"
            "pipefail"
            "-c"
            ''test "$(curl --fail --silent --show-error --max-time 10 --resolve newadmin.vpsfree.cz:443:127.0.0.1 https://newadmin.vpsfree.cz/healthz)" = ok''
          ];
        }
      ];
    };
  };
}
