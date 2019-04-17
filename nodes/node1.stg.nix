{ config, lib, ...}:

with (import ./lib.nix { inherit lib; });


/*
node1.stg ASN 4200001001
teng0 172.16.251.2/30 2a03:3b40:42:2:01::2/80
teng1 172.16.250.2/30 2a03:3b40:42:3:01::2/80

teng0 ASN: 4200001901 pro peery 172.16.251.1 2a03:3b40:42:2:01::1
teng1 ASN: 4200001902 pro peery 172.16.250.1 2a03:3b40:42:3:01::1
*/

let
  bgpAS = 4200001001;
in
{
  imports = [
    ./stg.nix
  ];

  services.udev.extraRules = mkNetUdevRules {
    "teng0" = "0c:c4:7a:88:69:d8";
    "teng1" = "0c:c4:7a:88:69:d9";
  };

  networking.hostName = "node1.stg";
  networking.custom = ''
    ip a add 172.16.251.2/30 dev teng0
    ip a add 172.16.250.2/30 dev teng1
    ip -6 a add 2a03:3b40:42:2:01::2/80 dev teng0
    ip -6 a add 2a03:3b40:42:3:01::2/80 dev teng1
    ip link set teng0 up
    ip link set teng1 up

    ip link add virtip type dummy
    ip addr add 172.16.0.26/32 dev virtip
    ip link set virtip up
  '';

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" "sdh" ];
      layout = [
        { type = "mirror"; devices = [ "sdc" "sdd" ]; }
        { type = "mirror"; devices = [ "sde" "sdf" ]; }
        { type = "mirror"; devices = [ "sdg" "sdh" ]; }
      ];
      log = [
        { mirror = true; devices = [ "sda1" "sdb1" ]; }
      ];
      cache = [ "sda2" "sdb2" ];
      partition = {
        sda = {
          p1 = { sizeGB=10; };
          p2 = {};
        };
        sdb = {
          p1 = { sizeGB=10; };
          p2 = {};
        };
      };
    };
  };

  #boot.kernelParams = [ "console=tty0" "console=ttyS0,115200" "panic=-1" ];
  #boot.consoleLogLevel = 4;

  vpsadmin.nodeId = 400;
  vpsadmin.consoleHost = "172.16.251.2";
  vpsadmin.netInterfaces = [ "teng0" "teng1" ];

  node.as = bgpAS;
  node.routerId = "172.16.251.2";
}
