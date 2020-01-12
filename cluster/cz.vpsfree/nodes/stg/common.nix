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
          sharenfs =
            let
              networks = data.networks.management.ipv4;
              property = lib.concatMapStringsSep "," (net:
                "rw=@${net.address}/${toString net.prefix}"
              ) networks;
            in property;
        };
        "reservation".properties = {
          refreservation = "100G";
          canmount = "off";
        };
      };
    };
  };
}
