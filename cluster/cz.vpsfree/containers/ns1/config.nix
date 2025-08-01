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
    ../../../../configs/public-dns/primary.nix
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin = {
      node_id = 11;
      node_name = "dns1.prg";
    };
  };

  system.stateVersion = "23.11";
}
