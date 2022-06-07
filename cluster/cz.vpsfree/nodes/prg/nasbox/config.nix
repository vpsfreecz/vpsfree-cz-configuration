{ config, lib, pkgs, ...}:
{
  imports = [
    ../../common/storage.nix
    ../../common/netboot.nix
  ];

  vpsadmin.nodectld = {
    netInterfaces = [ "oneg0" "oneg1" ];
    consoleHost = "172.16.0.6";
  };

  boot.kernelModules = [ "8021q" ];

  services.nfs.server.nfsd = {
    nproc = 16;
    udp = true;
  };

  boot.zfs.pools.storage = {
    guid = "2575935829831167981";

    scrub = {
      enable = true;
      startIntervals = [ "0 23 1 */2 *" ];
      pauseIntervals = [ "0 7 * * *" ];
      resumeIntervals = [ "1 23 * * *" ];
    };
  };
}
