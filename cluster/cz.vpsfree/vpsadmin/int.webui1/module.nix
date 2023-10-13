{ config, ... }:
{
  cluster."cz.vpsfree/vpsadmin/int.webui1" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "vpsadmin" ];
    container.id = 20275;
    host = { name = "webui1"; location = "int"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.9.130"; prefix = 32; } ];
    };
    services.node-exporter = {};
    tags = [ "vpsadmin" "webui" "auto-update" ];

    healthChecks = {
      systemd.unitProperties = {
        "phpfpm-vpsadmin-webui.service" = [
          { property = "ActiveState"; value = "active"; }
        ];

        "nginx.service" = [
          { property = "ActiveState"; value = "active"; }
        ];
      };

      machineCommands = [
        {
          description = "Check vpsAdmin webui";
          command = [ "curl" "--fail" "http://localhost" ];
          standardOutput.include = [
            "vpsAdmin"
            "</html>"
          ];
        }
      ];
    };
  };
}
