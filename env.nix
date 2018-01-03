{ config, pkgs, ... }:
{
  time.timeZone = "Europe/Amsterdam";
  networking.nameservers = [ "172.18.2.10" "172.18.2.11" "208.67.222.222" "208.67.220.220" ];
  services.openssh.enable = true;
  nix.useSandbox = true;
  nix.nrBuildUsers = 100;
  nix.buildCores = 0;
  systemd.tmpfiles.rules = [ "d /tmp 1777 root root 7d" ];

  environment.systemPackages = with pkgs; [
    wget
    vim
    screen
  ];

  users.extraUsers.root.openssh.authorizedKeys.keys =
    with import ./ssh-keys.nix; [ srk snajpa ];

}
