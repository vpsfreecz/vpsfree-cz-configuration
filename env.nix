{ config, pkgs, ... }:
{
  time.timeZone = "Europe/Amsterdam";
  networking.nameservers = pkgs.lib.mkDefault [ "172.18.2.10" "172.18.2.11" "208.67.222.222" "208.67.220.220" ];
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
