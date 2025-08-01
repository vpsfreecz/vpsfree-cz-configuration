{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ../../vpsadmin/common/all.nix
    ../../vpsadmin/common/dns.nix
    ../../../../configs/public-dns/secondary.nix
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin = {
      node_id = 12;
      node_name = "dns2.brq";
    };
  };

  system.stateVersion = "23.11";
}
