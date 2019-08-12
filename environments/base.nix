{ config, pkgs, data, ... }:
{
  time.timeZone = "Europe/Amsterdam";
  networking = {
    domain = "vpsfree.cz";
    search = ["vpsfree.cz" "prg.vpsfree.cz" "base48.cz"];
    nameservers = [ "172.18.2.10" "172.18.2.11" "1.1.1.1" ];
  };

  services.openssh.enable = true;
  nix.useSandbox = true;

  environment.systemPackages = with pkgs; [
    wget
    vim
    screen
  ];

  users.users.root.openssh.authorizedKeys.keys = with data; [
    sshKeys."build.vpsfree.cz"
    sshKeys.aither
    sshKeys.srk
    sshKeys.snajpa
  ];
}
