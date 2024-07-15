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

  system.stateVersion = "24.05";
}
