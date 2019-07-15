{ config, lib, ...}:

{
  imports = [
    ./common.nix
  ];

  node = {
    nodeId = 400;
    net = {
      hostName = "node1.stg";
      as = 4200001001;
      mac = {
        teng0 = "0c:c4:7a:88:69:d8";
        teng1 = "0c:c4:7a:88:69:d9";
      };
      interfaces = {
        teng0 = { v4 = "172.16.251.2/30";   v6 = "2a03:3b40:42:2:01::2/80"; };
        teng1 = { v4 = "172.16.250.2/30";   v6 = "2a03:3b40:42:3:01::2/80"; };
      };

      routerId = "172.16.251.2";
      bgp1neighbor = { v4 = "172.16.251.1"; v6 = "2a03:3b40:42:2:01::1"; };
      bgp2neighbor = { v4 = "172.16.250.1"; v6 = "2a03:3b40:42:3:01::1"; };

      virtIP = "172.16.0.26/32";
    };
  };

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
}
