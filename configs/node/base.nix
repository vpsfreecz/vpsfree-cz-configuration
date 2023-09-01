{ config, pkgs, lib, confLib, confData, confMachine, ... }:
with lib;
let
  cfg = confMachine;

  mapEachIp = fn: addresses:
    flatten (mapAttrsToList (ifname: ips:
      (map (addr: fn ifname 4 addr) ips.v4)
      ++
      (map (addr: fn ifname 6 addr) ips.v6)
    ) addresses);

  kernels = import ./kernels.nix { inherit pkgs lib; };
in {
  config = mkIf (confMachine.osNode != null) {
    boot.kernelVersion = mkDefault (kernels.getRuntimeKernelForMachine confMachine.name);

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

    system.monitoring.enable = true;
    osctl.exporter.port = confMachine.services.osctl-exporter.port;

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
