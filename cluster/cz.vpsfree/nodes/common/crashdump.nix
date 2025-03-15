{ config, pkgs, lib, confLib, confMachine, ... }:
let
  inherit (lib) concatStringsSep imap1 mapAttrsToList mkIf;

  backuper2Prg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/nodes/prg/backuper2";
  };

  networking = confMachine.osNode.networking;

  renameNetif = mac: newName: ''
    oldName=$(ip -o link | grep "${mac}" | awk -F': ' '{print $2}')

    if [ -n "$oldName" ]; then
      echo "  $oldName -> ${newName}"
      ip link set dev "$oldName" name "${newName}"
    else
      echo "  interface with ${mac} not found"
    fi

    oldName=
  '';

  setupNetif = name: addresses: ''
    ${concatStringsSep "\n" (map (addr: "ip -4 addr add ${addr.address}/${toString addr.prefix} dev ${name}") addresses.v4)}
    ip link set ${name} up
  '';
in mkIf (confMachine.osNode.networking.bird.enable && confMachine.osNode.networking.bird.routingProtocol == "bgp") {
  boot.initrd.kernelModules = [
    "lockd"
    "netfs"
    "nfsv4"
    "sunrpc"
  ];

  boot.initrd.network = {
    # Within the crash system, we're using 10G interfaces and so the DHCP
    # that configures 1G interfaces can and should be skipped.
    enableSetupInCrashDump = false;

    customSetupCommands = ''
      if grep -q this_is_a_crash_kernel /proc/cmdline ; then
        echo "Renaming network interfaces"
        ${concatStringsSep "\n" (mapAttrsToList (name: mac: renameNetif mac name) networking.interfaces.names)}

        echo "Configuring interfaces"
        ${concatStringsSep "\n" (mapAttrsToList (name: addresses: setupNetif name addresses) networking.interfaces.addresses)}

        echo "Adding default route"
        ${concatStringsSep "\n" (imap1 (i: n: "ip -4 route add default via ${n.address} metric ${toString (100 + i)}") networking.bird.bgpNeighbours.v4)}
      fi
    '';
  };

  boot.initrd.extraUtilsCommands = ''
    copy_bin_and_libs ${pkgs.nfs-utils}/bin/mount.nfs
  '';

  boot.crashDump = {
    enable = true;
    commands = ''
      date=$(date +%Y%m%dT%H%M%S)
      server="${backuper2Prg.addresses.primary.address}:/storage/vpsfree.cz/crashdump"
      mountpoint="/mnt/nfs"
      target="$mountpoint/${confMachine.name}/$date"

      echo "Mounting NFS"
      mkdir -p "$mountpoint"
      mount.nfs -o vers=4 "$server" "$mountpoint" || fail "Unable to mount NFS share"

      echo "Target dir $target"
      mkdir -p "$target"

      echo "Saving metadata"
      uname -r > "$target/kernel-version"
      echo "${config.system.vpsadminos.revision}" > "$target/os-revision"
      echo "${config.system.vpsadminos.version}" > "$target/os-version"

      echo "Dumping dmesg"
      makedumpfile --dump-dmesg /proc/vmcore "$target/dmesg"

      cpuCount=$(nproc)

      echo "Dumping core file using $cpuCount threads"
      LD_PRELOAD=$LD_LIBRARY_PATH/libgcc_s.so.1  makedumpfile -c -d 16 --num-threads $cpuCount /proc/vmcore "$target/dumpfile"

      echo "Rebooting"
      reboot -f
    '';
  };
}