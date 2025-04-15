{ config, lib, pkgs, confMachine, ... }:
{
  imports = [
    # While crash dump is not limited to netbooted machines, in practice, all nodes
    # are netbooted and other systems do not use boot.initrd.network, which is
    # required to upload the crash dump.
    ./crashdump.nix
  ];

  boot.initrd.kernelModules = [
    "igb" "ixgbe" "tg3"
  ];

  boot.initrd.network = {
    enable = true;
    useDHCP = true;
    preferredDHCPInterfaceMacAddresses = confMachine.netboot.macs;
    ssh = {
      enable = true;
      hostKeys = [
        /secrets/nodes/initrd/ssh_host_rsa_key
        /secrets/nodes/initrd/ssh_host_ed25519_key
      ];
    };
  };

  # NixOS initrd-ssh module does pkill -x sshd, which does not match
  # any processes
  boot.initrd.postMountCommands = ''
    if ! [ -e /.keep_sshd ]; then
      pkill sshd
    fi
  '';

  boot.consoleLogLevel = 8;

  boot.postBootCommands = ''
    chmod 0600 /var/secrets/ssh_host_*_key
    chmod 0644 /var/secrets/ssh_host_*_key.pub
    cp -p /var/secrets/ssh_host_* /etc/ssh/
  '';

  # Helper script for manual kexec from netboot server
  boot.initrd.extraUtilsCommands =
    let
      netbootKexec = ''
        #!/bin/sh
        # Usage: $0 [generation]

        generation=current
        kexec_files="bzImage initrd kernel-params"
        wdir=/tmp/kexec

        [ -n "$1" ] && generation="$1"

        # Find httproot in /proc/cmdline
        http_root="$(sed -n 's/.*httproot=\([^[:space:]]*\).*/\1/p' /proc/cmdline)"

        if [ -z "$http_root" ]; then
          echo "ERROR: Unable to find httproot= parameter in /proc/cmdline"
          exit 1
        fi

        # Strip the last two path components (like "../../")
        http_base="$(echo "$http_root" | sed 's!/[^/]*$!!; s!/[^/]*$!!')"

        # Build URL for the selected generation
        http_newurl="$http_base/$generation"
        echo "Base URL for kexec files: $http_newurl"

        # Download the necessary kernel/initrd/kernel-params
        mkdir -p "$wdir"

        for file in $kexec_files ; do
          wget "$http_newurl/$file" -O "$wdir/$file" || {
            echo "ERROR: Failed to download $file"
            exit 1
          }
        done

        # Load the new kernel
        kexec -l "$wdir/bzImage" --initrd="$wdir/initrd" --command-line="$(cat "$wdir/kernel-params")" || {
          echo "ERROR: kexec load failed"
          exit 1
        }

        echo "Kexec loaded, run kexec -e"
        exit 0
      '';
    in ''
      copy_bin_and_libs ${pkgs.kexec-tools}/bin/kexec

      cat <<'EOF' > $out/bin/netboot-kexec
      ${netbootKexec}
      EOF

      chmod +x $out/bin/netboot-kexec
    '';
}
