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

  environment.etc =
    let
      prefix = "/secrets/nodes/${ config.networking.hostName }/ssh";
      path = pkgs.copyPathToStore prefix;
    in {
      "ssh/ssh_host_rsa_key.pub".source = "${ path }/ssh_host_rsa_key.pub";
      "ssh/ssh_host_rsa_key" = { mode = "0600"; source = "${ path }/ssh_host_rsa_key"; };
      "ssh/ssh_host_ed25519_key.pub".source = "${ path }/ssh_host_ed25519_key.pub";
      "ssh/ssh_host_ed25519_key" = { mode = "0600"; source = "${ path }/ssh_host_ed25519_key"; };
    };
}
