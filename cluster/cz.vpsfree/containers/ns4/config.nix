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
      node_id = 14;
      node_name = "dns4.brq";
    };
  };

  system.stateVersion = "24.05";
}
