{ config, pkgs, lib, ... }:
{
  imports = [
    ../modules/deploy.nix
  ];

  networking.lxcbr = true;
  networking.hostName = "build";
  networking.dhcpd = true;

  users.users.root.openssh.authorizedKeys.keys =
    let
      sshKeys = import ../ssh-keys.nix;
    in [ sshKeys."build.vpsfree.cz" ];
}
