{ config, pkgs, lib, ... }:
let
  bondIfaces = [ "teng0" "teng1" ];
  bondVlan = 200;
  bondIP = "172.19.0.14/23";
in {
  imports = [
    ../common.nix
    ../../common/tunables-512g.nix
  ];

  hardware.cpu.amd.updateMicrocode = true;

  boot.initrd.kernelModules = [ "bnxt_en" ];

  boot.kernelModules = [ "bonding" "8021q" ];
  boot.extraModprobeConfig = "options bonding mode=1 miimon=100";

  networking.custom = ''
    ip link add bond0 type bond

    ${lib.flip lib.concatMapStrings bondIfaces (ifc: ''
      ip link set ${ifc} up
      ip link add link ${ifc} name ${ifc}.${toString bondVlan} master bond0 type vlan id ${toString bondVlan}
    '')}

    # Keep teng0 down, as these NICs are buggy and cause packet loss when both
    # of them are up.
    ip link set teng0 down

    ip link set bond0 up
    ip addr add ${bondIP} dev bond0
  '';

  boot.zfs.pools = {
    tank = {
      install = true;

      wipe = [
        "sdc" "sdd" "sde" "sdf" "sdg" "sdh" "sdi" "sdj" "sdk" "sdl" "nvme0n1"
      ];

      layout = [
        { type = "raidz"; devices = [ "sdc" "sdd" "sde" "sdf" "sdg" ]; }
        { type = "raidz"; devices = [ "sdh" "sdi" "sdj" "sdk" "sdl" ]; }
      ];

      log = [
        { mirror = false; devices = [ "nvme0n1p1" ]; }
      ];

      cache = [
        "nvme0n1p2"
      ];

      partition = {
        nvme0n1 = {
          p1 = { sizeGB=10; };
          p2 = { sizeGB=250; };
          p3 = {};
        };
      };

      properties = {
        ashift = "12";
      };
    };

    tank-node4 = {
      install = true;

      datasets = {
        "/".properties = {
          compression = "on";
          dnodesize = "legacy";
          recordsize = "128k";
          xattr = "sa";
        };
        "ct".properties = {
          acltype = "posixacl";
        };
        "reservation".properties = {
          refreservation = lib.mkDefault "100G";
          canmount = "off";
        };
      };

      scrub = {
        enable = true;
        startIntervals = [ "0 4 1-7 * *" ];
        startCommand = ''[ "$(LC_ALL=C date '+\%a')" = "Sun" ] && scrubctl start tank-node4'';
      };
    };
  };

  osctl.pools.tank = {
    parallelStart = 5;
    parallelStop = 12;
  };

  osctl.pools.tank-node4 = {
    parallelStart = 3;
    parallelStop = 8;
  };

  boot.enableUnifiedCgroupHierarchy = true;

  swapDevices = [
    # { label = "swap1"; }
  ];

  vpsadmin.nodectld.settings = {
    vpsadmin.net_interfaces = [ "bond0" ];
  };
}
