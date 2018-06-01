{ config, lib, pkgs, ...}:
{
  imports = [ ./common.nix ];

  networking.bonded = {
    enable = true;
    interfaces = lib.mkDefault [ "eth0" "eth1"];
    gw = "172.16.0.2";
    vlan = 200;
  };
}
