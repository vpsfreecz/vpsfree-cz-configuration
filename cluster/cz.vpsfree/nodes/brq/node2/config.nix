{ config, pkgs, lib, ...}:
let
  bondIfaces = [ "oneg0" "oneg1" ];
  bondVlan = 200;
  bondIP = "172.19.0.11/23";
in {
  imports = [
    ../common.nix
    ../../common/tank-hdd.nix
    ../../common/tunables-256g.nix
  ];

  boot.kernelModules = [ "bonding" "8021q" ];
  boot.extraModprobeConfig = ''
    options bonding mode=1 miimon=100
  '';

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
        "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" "sdh" "sdi" "sdj"
      ];

      layout = [
        { type = "mirror"; devices = [ "sdc" "sdd" ]; }
        { type = "mirror"; devices = [ "sde" "sdf" ]; }
        { type = "mirror"; devices = [ "sdg" "sdh" ]; }
        { type = "mirror"; devices = [ "sdi" "sdj" ]; }
      ];

      log = [
        { mirror = true; devices = [ "sda1" "sdb1" ]; }
      ];

      cache = [ "sda3" "sdb3" ];

      partition = {
        sda = {
          p1 = { sizeGB=10; };
          p2 = { sizeGB=214; };
          p3 = {};
        };
        sdb = {
          p1 = { sizeGB=10; };
          p2 = { sizeGB=214; };
          p3 = {};
        };
      };

      properties = {
        ashift = "12";
      };
    };
  };

  swapDevices = [
    # { label = "swap1"; }
  ];
}
