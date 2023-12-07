{ config, lib, pkgs, confData, ... }:
{
  imports = [
    ../../common/storage.nix
    ../../common/netboot.nix
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin = {
      net_interfaces = [ "teng0" "teng1" ];
      queues = {
        storage.threads = 8;
        zfs_recv.threads = 48;
      };
    };
    console = {
      enable = false;
    };
    mbuffer = {
      send = {
        buffer_size = "2G";
      };
      receive = {
        buffer_size = "1G";
        start_writing_at = 60;
      };
    };
  };

  boot.kernelModules = [ "8021q" "nvmet" "nvmet-tcp" "configfs" ];

  boot.zfs.pools = {
    storage = {
      guid = "13391792327079201350";

      install = false;

      scrub = {
        enable = true;
        startIntervals = [ "0 7 */30 * *" ];
        pauseIntervals = [ "0 1 * * *" ];
        resumeIntervals = [ "0 7 * * *" ];
      };
    };
  };
}
