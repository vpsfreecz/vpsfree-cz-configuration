{ config, lib, pkgs, confLib, confMachine, ... }:
let
  apuPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/machines/prg/apu";
  };
in {
  boot.initrd.kernelModules = [
    "igb" "ixgbe" "tg3"
  ];

  boot.initrd.network = {
    enable = true;
    useDHCP = true;
  };

  # While crash dump is not limited to netbooted machines, in practice, all nodes
  # are netbooted and other systems do not use boot.initrd.network, which is
  # required to upload the crash dump.
  boot.consoleLogLevel = 8;
  # boot.crashDump = {
  #   enable = true;
  #   execAfterDump = ''
  #     date=$(date +%Y%m%dT%H%M%S)
  #     tftp -l /dmesg -r /${confMachine.host.fqdn}-dmesg-$date -p ${apuPrg.addresses.primary.address} || exit 1
  #     reboot -f
  #   '';
  # };

  boot.postBootCommands = ''
    cp /var/secrets/ssh_host_* /etc/ssh/
    chmod 0600 /var/secrets/ssh_host_*_key
    chmod 0644 /var/secrets/ssh_host_*_key.pub
  '';
}
