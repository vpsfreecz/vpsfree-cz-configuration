{ config, pkgs, lib, confLib, confMachine, ... }:
let
  inherit (lib) concatStringsSep imap1 mapAttrsToList mkIf optionalString;

  backuper2Prg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/nodes/prg/backuper2";
  };

  networking = confMachine.osNode.networking;

  has10GNetwork = confMachine.osNode.networking.bird.enable && confMachine.osNode.networking.bird.routingProtocol == "bgp";

  customNetworking = has10GNetwork;

  dumpMemory = has10GNetwork;

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
in {
  boot.initrd.kernelModules = [
    "lockd"
    "netfs"
    "nfsv4"
    "sunrpc"
  ];

  # On nodes with 10G and BGP (Prague), we skip DHCP on 1G interfaces and configure
  # the network manually using the 10G interfaces. On nodes with 1G and OSPF (Brno),
  # we use the normal initrd setup with DHCP.
  boot.initrd.network = mkIf customNetworking {
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
    copy_bin_and_libs ${pkgs.kexec-tools}/bin/kexec
    copy_bin_and_libs ${pkgs.nfs-utils}/bin/mount.nfs
  '';

  boot.crashDump = {
    enable = true;
    reservedMemory = "1536M";
    commands = ''
      kexec_load() {
        local http_root http_base http_newurl kernel_cmdline kexec_files wdir

        kexec_files="bzImage initrd kernel-params"
        wdir=/tmp/kexec

        # Find httproot in /proc/cmdline
        http_root="$(sed -n 's/.*httproot=\([^[:space:]]*\).*/\1/p' /proc/cmdline)"

        if [ -z "$http_root" ]; then
          echo "ERROR: Unable to find httproot= parameter in /proc/cmdline"
          return 1
        fi

        # Strip the last two path components (like "../../")
        http_base="$(echo "$http_root" | sed 's!/[^/]*$!!; s!/[^/]*$!!')"

        # Build URL for the current generation
        http_newurl="$http_base/current"
        echo "Base URL for kexec files: $http_newurl"

        # Download the necessary kernel/initrd/kernel-params
        mkdir -p "$wdir"

        for file in $kexec_files ; do
          wget "$http_newurl/$file" -O "$wdir/$file" || {
            echo "ERROR: Failed to download $file"
            return 1
          }
        done

        # Load the new kernel
        kexec -l "$wdir/bzImage" --initrd="$wdir/initrd" --command-line="$(cat "$wdir/kernel-params")" || {
          echo "ERROR: kexec load failed"
          return 1
        }

        echo "Kexec loaded"
        return 0
      }

      create_crash_dump() {
        local date server mountpoint target cpuCount

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

        ${optionalString dumpMemory ''
        cpuCount=$(nproc)

        echo "Dumping core file using $cpuCount threads"
        LD_PRELOAD=$LD_LIBRARY_PATH/libgcc_s.so.1 makedumpfile -c -d 16 --num-threads $cpuCount /proc/vmcore "$target/dumpfile"
        ''}
      }

      use_kexec=0

      echo "Preparing for kexec"
      kexec_load && use_kexec=1

      echo "Creating crash dump"
      create_crash_dump

      if [ "$use_kexec" == "1" ] ; then
        echo "Executing kexec"
        kexec -e
      else
        echo "Rebooting"
        reboot -f
      fi
    '';
  };
}