{ config, pkgs, lib, ... }:
let
  bondIfaces = [ "oneg0" "oneg1" ];
  bondVlan = 200;
  bondIP = "172.19.0.15/23";
in {
  imports = [
    ../common.nix
    ../../common/amd.nix
    ../../common/tunables-1t.nix
  ];

  boot.initrd.kernelModules = [ "bnxt_en" ];

  boot.kernelModules = [ "bonding" "8021q" ];
  boot.extraModprobeConfig = "options bonding mode=1 miimon=100";

  networking.custom = ''
    ip link add bond0 type bond

    ${lib.flip lib.concatMapStrings bondIfaces (ifc: ''
      ip link set ${ifc} up
      ip link add link ${ifc} name ${ifc}.${toString bondVlan} master bond0 type vlan id ${toString bondVlan}
    '')}

    ip link set bond0 up
    ip addr add ${bondIP} dev bond0
  '';

  boot.zfs.pools = {
    tank = {
      install = true;

      wipe = [
        "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1"
      ];

      layout = [
        { type = "raidz"; devices = [ "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" ]; }
      ];

      properties = {
        ashift = "12";
      };

      datasets = {
        "reservation".properties = {
          refreservation = "500G";
        };
      };
    };
  };

  osctl.pools.tank = {
    parallelStart = 10;
    parallelStop = 20;
  };

  boot.enableUnifiedCgroupHierarchy = false;

  swapDevices = [
    # none
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin.net_interfaces = [ "bond0" ];
  };
}
