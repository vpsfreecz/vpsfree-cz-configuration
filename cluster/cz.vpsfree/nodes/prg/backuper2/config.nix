{
  config,
  lib,
  pkgs,
  confData,
  ...
}:
let
  inherit (lib) concatMapStringsSep "\n";

  crashdumpNetworks = with confData.vpsadmin.networks.management; ipv4 ++ dev ++ dhcp;
in
{
  imports = [
    ../../common/intel.nix
    ../../common/storage.nix
    ../../common/netboot.nix
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin = {
      net_interfaces = [
        "teng0"
        "teng1"
      ];
      queues = {
        storage.threads = 4;
        zfs_recv.threads = 36;
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

  boot.kernelModules = [
    "8021q"
    "nvmet"
    "nvmet-tcp"
    "configfs"
  ];

  boot.zfs.pools = {
    storage = {
      guid = "13391792327079201350";

      install = false;

      datasets = {
        "vpsfree.cz/crashdump".properties = {
          sharenfs = concatMapStringsSep "," (
            net: "rw=${net.address}/${toString net.prefix},no_root_squash"
          ) crashdumpNetworks;
        };
      };

      scrub = {
        enable = true;
        startIntervals = [ "0 7 */30 * *" ];
        pauseIntervals = [ "0 1 * * *" ];
        resumeIntervals = [ "0 7 * * *" ];
      };
    };
  };

  boot.enableUnifiedCgroupHierarchy = true;
}
