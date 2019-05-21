{ config, pkgs, ... }:
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

  security.sudo.enable = true;

  users.extraUsers.root.openssh.authorizedKeys.keys =
    with import ./ssh-keys.nix; [ aither srk snajpa ];

}
