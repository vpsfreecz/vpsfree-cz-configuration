{ config, ... }:
{
  cluster."cz.vpsfree/containers/prg/int.mon2" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    container.id = 19501;
    host = { name = "mon2"; location = "int.prg"; domain = "vpsfree.cz"; };
    addresses = {
      v4 = [ { address = "172.16.4.18"; prefix = 32; } ];
    };
    services = {
      node-exporter = {};
      prometheus = {};
    };
    monitoring.isMonitor = true;
    tags = [ "monitor" "all-internal-dns" "auto-update" ];
    healthChecks = import ../../../../../health-checks/monitoring.nix;
  };
}
