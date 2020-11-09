{ config, pkgs, lib, confData, swpins, ... }:
with lib;
{
  time.timeZone = "Europe/Amsterdam";

  networking = {
    search = ["vpsfree.cz" "prg.vpsfree.cz" "base48.cz"];
    nameservers = [ "172.16.9.90" "1.1.1.1" ];
  };

  services.openssh.enable = true;

  nix.useSandbox = true;

  nix.nixPath = [
    "nixpkgs=${swpins.nixpkgs}"
  ] ++ (optional (hasAttr "vpsadminos" swpins) "vpsadminos=${swpins.vpsadminos}");

  environment.systemPackages = with pkgs; [
    wget
    vim
    screen
  ];

  users.users.root.openssh.authorizedKeys.keys = with confData.sshKeys; admins ++ builders;
}
