{ pkgs, lib, config, ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ../../vpsadmin/common/all.nix
    ../../vpsadmin/common/dns.nix
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin = {
      node_id = 13;
      node_name = "dns3.prg";
    };
  };

  # The monitoring system checks authoritative servers by querying
  # vpsfree.cz, so provide the zone
  services.bind = {
    zones = import ../../../../configs/public-dns/zones.nix {
      inherit lib;
      primary = false;
      filterZones = zone: zone.name == "vpsfree.cz.";
    };
  };

  system.stateVersion = "24.05";
}
