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

  boot.zfs.pools = {
    tank = {
      datasets = {
        "/".properties = {
          compression = "on";
        };
        "ct".properties = {
          acltype = "posixacl";
          sharenfs = "rw=@172.16.0.0/23,rw=@172.16.2.0/23,rw=@172.19.0.0/23";
        };
      };
    };
  };

  #networking.bonded = {
  #  enable = true;
  #  interfaces = lib.mkDefault [ "eth0" "eth1"];
  #  gw = "172.16.0.2";
  #  vlan = 200;
  #};
}
