{ config, lib, pkgs, ...}:
{
  imports = [
    ./common.nix
    ./modules/bird.nix
  ];

  environment.systemPackages = with pkgs; [
    git
  ];

  programs.bash.root.historyPools = [ "tank" ];

  #networking.bonded = {
  #  enable = true;
  #  interfaces = lib.mkDefault [ "eth0" "eth1"];
  #  gw = "172.16.0.2";
  #  vlan = 200;
  #};
}
