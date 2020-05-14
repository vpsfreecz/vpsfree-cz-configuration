{ config, pkgs, data, ... }:
{
  time.timeZone = "Europe/Amsterdam";
  networking = {
    domain = "vpsfree.cz";
    search = ["vpsfree.cz" "prg.vpsfree.cz" "base48.cz"];
    nameservers = [ "172.16.9.90" "1.1.1.1" ];
  };

  services.openssh.enable = true;
  nix.useSandbox = true;

  environment.systemPackages = with pkgs; [
    wget
    vim
    screen
  ];

  users.users.root.openssh.authorizedKeys.keys = with data.sshKeys; admins ++ builders;

  security.acme = {
    acceptTerms = true;
    email = "podpora@vpsfree.cz";
  };
}
