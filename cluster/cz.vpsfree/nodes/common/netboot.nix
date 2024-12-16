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
}
