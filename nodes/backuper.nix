{ config, lib, pkgs, ...}:
let
  bondIfaces = [ "eth0" "eth1" "eth2" "eth3" ];
  bondVlan = 200;
  bondIP = "172.16.0.5/23";
  bondGateway = "172.16.0.2";
in
{
  imports = [
    ./storage.nix
  ];

  boot.kernelModules = [ "bonding" "8021q" ];
  boot.extraModprobeConfig = "options bonding mode=balance-xor miimon=100 xmit_hash_policy=layer3+4 max_bonds=0";

  networking.hostName = "backuper";
  networking.custom = ''
    ip link add bond0 type bond
    ${lib.flip lib.concatMapStrings bondIfaces (ifc:
      ''
        ip link set ${ifc} up
        ip link add link ${ifc} name ${ifc}.${bondVlan} master bond0 type vlan id ${bondVlan}
      ''
    )}
    ip link set bond0 up

    ip addr add ${bondIP} dev bond0
    ip route add default via ${bondGateway} dev bond0
  '';

  boot.zfs.pools = {
    storage = {
      layout = [
        #{ type = "raidz1"; devices = [ ]; }
      ];
      cache = [
        "wwn-0x5e83a97e60d6c045-part2"
        "wwn-0x5e83a97e71bd0af8-part2"
      ];
    };
  };

  vpsadmin.nodeId = 160;
}
