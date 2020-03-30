{ config, lib, pkgs, data, ... }:
{
  imports = [
    ../common.nix
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
        };
        "reservation".properties = {
          refreservation = "100G";
          canmount = "off";
        };
      };
    };
  };

  boot.kernelParams = [
    "intel_idle.max_cstate=1"
  ];
}
