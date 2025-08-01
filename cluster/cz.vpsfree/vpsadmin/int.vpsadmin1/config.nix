{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../common/all.nix
    ../common/mailer.nix
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin = {
      node_id = 5;
      node_name = "vpsadmin1.prg";
    };
  };

  system.stateVersion = "22.05";
}
