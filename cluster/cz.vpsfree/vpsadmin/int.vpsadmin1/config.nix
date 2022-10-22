{ pkgs, lib, config, ... }:
{
  imports = [
    ../common/all.nix
    ../common/mailer.nix
  ];

  vpsadmin.nodectld.settings.vpsadmin.node_id = 5;

  system.stateVersion = "22.05";
}
