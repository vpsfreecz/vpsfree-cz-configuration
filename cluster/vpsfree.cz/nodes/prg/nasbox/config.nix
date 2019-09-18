{ config, lib, pkgs, ...}:
let
  bondIfaces = [ "oneg0" "oneg1" "oneg2" "oneg3" ];
  bondVlan = 200;
  bondIP = "172.16.0.6/23";
  bondGateway = "172.16.0.1";
in
{
  imports = [
    ../../storage.nix
  ];

  vpsadmin.netInterfaces = [ "oneg0" "oneg1" ];
  vpsadmin.consoleHost = "172.16.0.6";

  boot.kernelModules = [ "bonding" "8021q" ];
  boot.extraModprobeConfig = "options bonding mode=balance-xor miimon=100 xmit_hash_policy=layer3+4 max_bonds=0";

  networking.custom = ''
    ip link add bond0 type bond
    ${lib.flip lib.concatMapStrings bondIfaces (ifc:
      ''
        ip link set ${ifc} up
        ip link add link ${ifc} name ${ifc}.${toString bondVlan} master bond0 type vlan id ${toString bondVlan}
      ''
    )}
    ip link set bond0 up

    ip addr add ${bondIP} dev bond0
    ip route add default via ${bondGateway} dev bond0

  '';

  boot.zfs.pools.storage = {};
}
