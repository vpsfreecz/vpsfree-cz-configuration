{ pkgs, lib, config, ... }:
{
  imports = [
    ../common/all.nix
    ../common/mailer.nix
  ];

  vpsadmin.nodectld.nodeId = 5;

  system.stateVersion = "22.05";
}
