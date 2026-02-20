{
  config,
  pkgs,
  lib,
  confLib,
  confMachine,
  pinsInfo,
  ...
}:
let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    imap1
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
      builtins.genList (i: "dumpfile${i + 1}") cfg.dumpFileCount;
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
          Number of threads for makedumpfile
        '';
      };

      disk = {
        device = mkOption {
          type = types.str;
          description = ''
            Device to be mounted
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
    boot.initrd.kernelModules = [
      "lockd"
      "netfs"
      "nfsv4"
      "sunrpc"
    ];

    # On nodes with 10G and BGP (Prague), we skip DHCP on 1G interfaces and configure
    # the network manually using the 10G interfaces. On nodes with 1G and OSPF (Brno),
    # we use the normal initrd setup with DHCP.
    boot.initrd.network = mkIf (cfg.destination == "disk" || customNetworking) {
      enableSetupInCrashDump = false;

      customSetupCommands = mkIf (cfg.destination != "disk" && customNetworking) ''
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
      reservedMemory = "2048M";
      commands = ''
        create_crash_dump() {
          local date mountpoint target cpuCount

          date=$(date +%Y%m%dT%H%M%S)
          mountpoint="/mnt/crashdump"
          target="$mountpoint/${confMachine.name}/$date"

          mkdir -p "$mountpoint"

          ${optionalString (cfg.destination == "nfs") ''
            local server
            server="${nfsTarget.addresses.primary.address}:${cfg.nfs.path}"

            echo "Mounting NFS"
            mount.nfs -o vers=4 "$server" "$mountpoint" || fail "Unable to mount NFS share"
          ''}

          ${optionalString (cfg.destination == "disk") ''
            echo "Mounting ${cfg.disk.device}"
            mount "${cfg.disk.device}" "$mountpoint" || fail "Unable to mount ${cfg.disk.device}"
          ''}

          echo "Target dir $target"
          mkdir -p "$target"

          echo "Saving metadata"
          uname -r > "$target/kernel-version"
          echo "${config.system.vpsadminos.revision}" > "$target/os-revision"
          echo "${config.system.vpsadminos.version}" > "$target/os-version"
          cat <<EOF > "$target/pins-info.json"
        ${builtins.toJSON pinsInfo}
        EOF

          ${optionalString cfg.dumpDmesg ''
            echo "Dumping dmesg"
            makedumpfile --dump-dmesg /proc/vmcore "$target/dmesg"
          ''}

          ${optionalString cfg.dumpMemory ''
            cpuCount=${if isNull cfg.threadCount then "$(nproc)" else toString cfg.threadCount}

            echo "Dumping core file using $cpuCount threads"
            LD_PRELOAD=$LD_LIBRARY_PATH/libgcc_s.so.1 \
              makedumpfile \
              ${optionalString cfg.enableCompression "-c"} \
              -d ${toString cfg.dumpLevel} \
              --num-threads $cpuCount \
              ${optionalString (cfg.dumpFileCount > 1) "--split"} \
              /proc/vmcore \
              ${concatMapStringsSep " " (v: "\"$target/${v}\"") dumpFileNames}
          ''}
        }

        echo "Creating crash dump"
        create_crash_dump

        echo "Syncing filesystems"
        sync

        echo "Rebooting"
        reboot -f
      '';
    };
  };
}
