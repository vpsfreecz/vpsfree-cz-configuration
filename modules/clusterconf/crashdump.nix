{
  config,
  pkgs,
  lib,
  confLib,
  confMachine,
  inputsInfo,
  ...
}:
let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    imap1
    isNull
    mapAttrsToList
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    optionalString
    types
    ;

  cfg = config.clusterconf.crashdump;

  nfsTarget = confLib.findMetaConfig {
    cluster = config.cluster;
    name = cfg.nfs.targetMachine;
  };

  networking = confMachine.osNode.networking;

  has10GNetwork =
    confMachine.osNode.networking.bird.enable
    && confMachine.osNode.networking.bird.routingProtocol == "bgp";

  customNetworking = has10GNetwork;

  needCrashNetwork = cfg.destination == "nfs" || cfg.debug;

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
    ${concatStringsSep "\n" (
      map (addr: "ip -4 addr add ${addr.address}/${toString addr.prefix} dev ${name}") addresses.v4
    )}
    ip link set ${name} up
  '';

  dumpFileNames =
    if cfg.dumpFileCount == 1 then
      [ "dumpfile" ]
    else
      builtins.genList (i: "dumpfile${toString (i + 1)}") cfg.dumpFileCount;

  useSplitDiskDevices = cfg.destination == "disk" && cfg.disk.devices != [ ];

  splitDiskMountCommands = concatStringsSep "\n" (
    imap1 (i: device: ''
      mountpoint${toString i}="/mnt/crashdump${toString i}"
      target${toString i}="$mountpoint${toString i}/${confMachine.name}/$date"

      mkdir -p "$mountpoint${toString i}"

      echo "Mounting ${device} on $mountpoint${toString i}"
      mount ${
        optionalString (cfg.disk.fsType != null) "-t ${cfg.disk.fsType} "
      }"${device}" "$mountpoint${toString i}" \
        || fail "Unable to mount ${device}"

      mkdir -p "$target${toString i}"
    '') cfg.disk.devices
  );

  splitDiskDumpFilePaths = concatStringsSep " " (
    imap1 (i: name: "\"$target${toString i}/${name}\"") dumpFileNames
  );

  splitDiskLayout = concatStringsSep "\n" (
    imap1 (i: device: "${builtins.elemAt dumpFileNames (i - 1)} ${device}") cfg.disk.devices
  );
in
{
  options = {
    clusterconf.crashdump = {
      enable = mkEnableOption "Enable crashdump";

      destination = mkOption {
        type = types.enum [
          "disk"
          "nfs"
        ];
        default = "nfs";
        description = ''
          Choose whether the crash dump is uplaoded over NFS or saved to a local disk
        '';
      };

      dumpDmesg = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Dump kernel log
        '';
      };

      dumpMemory = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Dump system memory
        '';
      };

      debug = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Keep the crashdump system running after the dump attempt and start an
          interactive shell. When the shell exits, a new shell is started and
          the machine stays up until rebooted manually.
        '';
      };

      inspect = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable in-place vmcore inspection from the crash kernel using
            crash(8) before optional memory dumping.

            When disabled, the crash initrd stays on the original lightweight
            makedumpfile-only path.
          '';
        };
      };

      dumpLevel = mkOption {
        type = types.ints.between 0 31;
        default = 16;
        description = ''
          Dump level for makedumpfile
        '';
      };

      dumpFileCount = mkOption {
        type = types.ints.positive;
        default = 1;
        description = ''
          Number of dump files to be created

          If the number is greater than one, `makedumpfile --split` is used.
        '';
      };

      enableCompression = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Compress memory dump
        '';
      };

      threadCount = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = ''
          Number of threads for makedumpfile.

          Ignored when `dumpFileCount` is greater than one, because
          `makedumpfile --split` cannot be combined with `--num-threads`.
        '';
      };

      prepareCommands = mkOption {
        type = types.lines;
        default = "";
        example = ''
          mdadm --assemble --scan || fail "Unable to assemble MD RAID arrays"
        '';
        description = ''
          Shell commands to run in the crash kernel before mounting the configured
          crashdump destination.

          This can be used to prepare local storage, for example by assembling an
          MD RAID array and exposing it under `disk.device`. On nodes using MD RAID,
          enable `boot.swraid.enable` so that `mdadm` and the required kernel modules
          are available in the initrd.
        '';
      };

      disk = {
        device = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Device to be mounted when storing the dump on a single local filesystem
          '';
        };

        devices = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Devices to be mounted separately when split dump files should be written
            to multiple local filesystems.

            When set, `dumpFileCount` must match the number of devices.
          '';
        };

        fsType = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Filesystem type used when mounting local crashdump storage
          '';
        };
      };

      nfs = {
        targetMachine = mkOption {
          type = types.str;
          default = "cz.vpsfree/nodes/prg/backuper2";
          description = ''
            Target machine where the crash dump is uploaded
          '';
        };

        path = mkOption {
          type = types.str;
          default = "/storage/vpsfree.cz/crashdump";
          description = ''
            Path on target machine to be mounted
          '';
        };
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.destination != "disk"
          || (
            (cfg.disk.device != null && cfg.disk.devices == [ ])
            || (cfg.disk.device == null && cfg.disk.devices != [ ])
          );
        message = "clusterconf.crashdump.disk: set either disk.device or disk.devices when destination = \"disk\"";
      }
      {
        assertion = !useSplitDiskDevices || cfg.dumpFileCount == builtins.length cfg.disk.devices;
        message = "clusterconf.crashdump.disk.devices: dumpFileCount must match the number of devices";
      }
    ];

    boot.initrd.kernelModules = [
      "lockd"
      "netfs"
      "nfsv4"
      "sunrpc"
    ];

    # On nodes with 10G and BGP (Prague), we skip DHCP on 1G interfaces and configure
    # the network manually using the 10G interfaces. On nodes with 1G and OSPF (Brno),
    # we use the normal initrd setup with DHCP whenever the crash kernel needs network
    # access (NFS upload or the debug shell over initrd SSH).
    boot.initrd.network = mkIf (customNetworking || !needCrashNetwork) {
      enableSetupInCrashDump = !customNetworking && needCrashNetwork;

      customSetupCommands = mkIf (customNetworking && needCrashNetwork) ''
        if grep -q this_is_a_crash_kernel /proc/cmdline ; then
          echo "Renaming network interfaces"
          ${concatStringsSep "\n" (
            mapAttrsToList (name: mac: renameNetif mac name) networking.interfaces.names
          )}

          echo "Configuring interfaces"
          ${concatStringsSep "\n" (
            mapAttrsToList (name: addresses: setupNetif name addresses) networking.interfaces.addresses
          )}

          echo "Adding default route"
          ${concatStringsSep "\n" (
            imap1 (
              i: n: "ip -4 route add default via ${n.address} metric ${toString (100 + i)}"
            ) networking.bird.bgpNeighbours.v4
          )}
        fi
      '';
    };

    boot.initrd.extraUtilsCommands = mkIf (cfg.destination == "nfs") ''
      copy_bin_and_libs ${pkgs.nfs-utils}/bin/mount.nfs
    '';

    boot.crashDump = {
      enable = true;
      inspect.enable = mkDefault cfg.inspect.enable;
      reservedMemory = "2048M";
      commands = ''
        create_crash_dump() {
          local date mountpoint target cpuCount

          date=$(date +%Y%m%dT%H%M%S)
          mountpoint="/mnt/crashdump"
          target="$mountpoint/${confMachine.name}/$date"

          mkdir -p "$mountpoint"

          ${optionalString (cfg.prepareCommands != "") ''
            echo "Preparing crashdump destination"
            ${cfg.prepareCommands}
          ''}

          ${optionalString (cfg.destination == "nfs") ''
            local server
            server="${nfsTarget.addresses.primary.address}:${cfg.nfs.path}"

            echo "Mounting NFS"
            mount.nfs -o vers=4 "$server" "$mountpoint" || fail "Unable to mount NFS share"
          ''}

          ${optionalString (cfg.destination == "disk") ''
            ${optionalString useSplitDiskDevices ''
              ${splitDiskMountCommands}
              target="$target1"
            ''}

            ${optionalString (!useSplitDiskDevices) ''
              echo "Mounting ${cfg.disk.device}"
              mount ${
                optionalString (cfg.disk.fsType != null) "-t ${cfg.disk.fsType} "
              }"${cfg.disk.device}" "$mountpoint" \
                || fail "Unable to mount ${cfg.disk.device}"
            ''}
          ''}

          echo "Target dir $target"
          mkdir -p "$target"

          ${optionalString useSplitDiskDevices ''
              echo "Saving split dump layout"
              cat <<EOF > "$target/dumpfile-layout"
            ${splitDiskLayout}
            EOF
          ''}

          echo "Saving metadata"
          uname -r > "$target/kernel-version"
          echo "${config.system.vpsadminos.revision}" > "$target/os-revision"
          echo "${config.system.vpsadminos.version}" > "$target/os-version"
          cat <<EOF > "$target/inputs-info.json"
        ${builtins.toJSON inputsInfo}
        EOF

          ${optionalString cfg.dumpDmesg ''
            echo "Dumping dmesg"
            makedumpfile --dump-dmesg /proc/vmcore "$target/dmesg"
          ''}

          ${optionalString cfg.inspect.enable ''
            echo "Collecting crash inspection data"
            mkdir -p "$target/inspect"
            if crash-collect "$target/inspect"; then
              echo 0 > "$target/inspect.exit-status"
            else
              rc=$?
              echo "$rc" > "$target/inspect.exit-status"
              echo "crash-collect failed with $rc"
            fi
          ''}

          ${optionalString cfg.dumpMemory ''
            ${optionalString (cfg.dumpFileCount == 1) ''
              cpuCount=${if isNull cfg.threadCount then "$(nproc)" else toString cfg.threadCount}
              echo "Dumping core file using $cpuCount threads"
            ''}

            ${optionalString (cfg.dumpFileCount > 1) ''
              echo "Dumping core file in split mode"
            ''}

            LD_PRELOAD=$LD_LIBRARY_PATH/libgcc_s.so.1 \
              makedumpfile \
              ${optionalString cfg.enableCompression "-c"} \
              -d ${toString cfg.dumpLevel} \
              ${optionalString (cfg.dumpFileCount == 1) "--num-threads $cpuCount"} \
              ${optionalString (cfg.dumpFileCount > 1) "--split"} \
              /proc/vmcore \
              ${
                if useSplitDiskDevices then
                  splitDiskDumpFilePaths
                else
                  concatMapStringsSep " " (v: "\"$target/${v}\"") dumpFileNames
              }
          ''}
        }

        echo "Creating crash dump"
        create_crash_dump

        echo "Syncing filesystems"
        sync

        ${optionalString cfg.debug ''
          echo "Crashdump debug mode enabled, starting interactive shell"
          ${optionalString cfg.inspect.enable ''
            echo "Run 'crash-vmcore' from the shell to inspect /proc/vmcore interactively"
          ''}
          while true; do
            setsid sh -c "exec sh < /dev/$console >/dev/$console 2>/dev/$console"
            echo "Interactive shell exited, starting a new shell"
            sleep 1
          done
        ''}

        echo "Rebooting"
        reboot -f
      '';
    };
  };
}
