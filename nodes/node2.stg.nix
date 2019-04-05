{ config, lib, ...}:

with (import ./lib.nix { inherit lib; });

/*
node2.stg ASN 4200001002
teng0 172.16.251.6/30 2a03:3b40:42:2:02::2/80
teng1 172.16.250.6/30 2a03:3b40:42:3:02::2/80

teng0 ASN: 4200001901 pro peery 172.16.251.6 2a03:3b40:42:2:02::1
teng1 ASN: 4200001902 pro peery 172.16.250.6 2a03:3b40:42:3:02::1
*/

{
  imports = [
    ./stg.nix
  ];

  services.udev.extraRules = mkNetUdevRules {
    "teng0" = "0c:c4:7a:88:70:14";
    "teng1" = "0c:c4:7a:88:70:15";
  };

  networking.hostName = "node2.stg";
  networking.custom = ''
    ip a add 172.16.251.6/30 dev teng0
    ip a add 172.16.250.6/30 dev teng1
    ip -6 a add 2a03:3b40:42:2:02::2/80 dev teng0
    ip -6 a add 2a03:3b40:42:3:02::2/80 dev teng1
    ip link set teng0 up
    ip link set teng1 up
  '';


  #boot.kernelParams = [ "console=tty0" "console=ttyS0,115200" "panic=-1" ];
  #boot.consoleLogLevel = 4;

  boot.zfs.pools = {
    tank = {
      doCreate = true; # XXX
      install = true;
      wipe = [ "sda" "sdb" "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" ];
      layout = [
        { type = "raidz2"; devices = [ "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" ]; }
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

  vpsadmin.nodeId = 401;
  vpsadmin.consoleHost = "172.16.251.6";
  vpsadmin.netInterfaces = [ "teng0" "teng1" ];
  networking.bird.routerId = "172.16.251.6";
  networking.bird6.routerId =  "172.16.251.6";
}
