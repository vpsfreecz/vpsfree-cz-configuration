{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.alerts2" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 19502;
    host = { name = "alerts2"; location = "int.prg"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.4.19"; prefix = 32; } ];
    };
    services = {
      alertmanager = {};
      node-exporter = {};
    };
    tags = [ "alerter" "auto-update" ];

    healthChecks = {
      systemd.unitProperties = {
        "alertmanager.service" = [
          { property = "ActiveState"; value = "active"; }
        ];

        "sachet.service" = [
          { property = "ActiveState"; value = "active"; }
        ];
      };
    };
  };
}
