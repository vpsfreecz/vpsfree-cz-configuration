{ config, lib, ...}:
{
  imports = [
    ./common.nix
  ];

  node = {
    nodeId = 401;
    net = {
      hostName = "node2.stg";
      as = 4200001002;
      mac = {
        teng0 = "0c:c4:7a:88:70:14";
        teng1 = "0c:c4:7a:88:70:15";
      };
      interfaces = {
        teng0 = { v4 = "172.16.251.6/30";   v6 = "2a03:3b40:42:2:02::2/80"; };
        teng1 = { v4 = "172.16.250.6/30";   v6 = "2a03:3b40:42:3:02::2/80"; };
      };

      routerId = "172.16.251.6";
      bgp1neighbor = { v4 = "172.16.251.5"; v6 = "2a03:3b40:42:2:02::1"; };
      bgp2neighbor = { v4 = "172.16.250.5"; v6 = "2a03:3b40:42:3:02::1"; };

      virtIP = "172.16.0.66/32";
    };
  };

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" ];
      layout = [
        { type = "raidz"; devices = [ "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" ]; }
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
}
