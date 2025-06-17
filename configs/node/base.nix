{ config, pkgs, lib, confLib, confData, confMachine, swpinsInfo, ... }:
with lib;
let
  cfg = confMachine;

  mapEachIp = fn: addresses:
    flatten (mapAttrsToList (ifname: ips:
      (map (addr: fn ifname 4 addr) ips.v4)
      ++
      (map (addr: fn ifname 6 addr) ips.v6)
    ) addresses);

  kernels = import ./kernels.nix { inherit pkgs lib config; };
in {
  config = mkIf (confMachine.osNode != null) {
    boot.kernelVersion = mkDefault (kernels.getRuntimeKernelForMachine confMachine.name);

    boot.postBootCommands = concatStringsSep "\n" (mapAttrsToList (swpin: spec:
      ''echo "swpin ${swpin}=${spec.rev}" > /dev/kmsg''
    ) swpinsInfo);

    vpsadmin.nodectld.settings = {
      vpsadmin = {
        node_id = cfg.node.id;
        net_interfaces = mkDefault (lib.attrNames cfg.osNode.networking.interfaces.addresses);
      };
      console = {
        host = mkDefault confMachine.addresses.primary.address;
      };
    };

    services.udev.extraRules = confLib.mkNetUdevRules cfg.osNode.networking.interfaces.names;
    services.rsyslogd.hostName = confMachine.name;

    networking.hostName = confMachine.host.fqdn;
    networking.custom = ''
      ${concatStringsSep "\n" (mapEachIp (ifname: v: addr: ''
      ip -${toString v} addr add ${addr.string} dev ${ifname}
      '') cfg.osNode.networking.interfaces.addresses)}

      ${concatStringsSep "\n" (mapAttrsToList (ifname: ips: ''
        ip link set ${ifname} up
      '') cfg.osNode.networking.interfaces.addresses)}

      ${optionalString (!isNull cfg.osNode.networking.virtIP) ''
      ip link add virtip type dummy
      ip addr add ${cfg.osNode.networking.virtIP.string} dev virtip
      ip link set virtip up
      ''}
    '';

    confctl.programs.kexec-netboot.enable = true;

    runit.halt.hooks = {
      "kexec-netboot".source = pkgs.writeScript "kexec-netboot" ''
        #!${pkgs.bash}/bin/bash

        [ "$HALT_HOOK" != "pre-run" ] && exit 0
        [ "$HALT_ACTION" != "reboot" ] && exit 0
        [ "$HALT_FORCE" != "0" ] && exit 0
        [ "$HALT_KEXEC" == "0" ] && exit 0

        echo "Configuring kexec from netboot server"
        echo "Use --no-kexec to skip it"
        echo

        kexec-netboot
        exit $?
      '';
    };

    system.monitoring.enable = true;

    users = {
      users.ssh-check = {
        isSystemUser = true;
        shell = pkgs.bash;
        group = "ssh-check";
        openssh.authorizedKeys.keys = with confData.sshKeys; [ ssh-exporter ];
      };

      groups.ssh-check = {};
    };
  };
}
