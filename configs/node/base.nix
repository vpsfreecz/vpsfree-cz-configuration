{ config, lib, confLib, confData, confMachine, ... }:
with lib;
let
  cfg = confMachine;

  mapEachIp = fn: addresses:
    flatten (mapAttrsToList (ifname: ips:
      (map (addr: fn ifname 4 addr) ips.v4)
      ++
      (map (addr: fn ifname 6 addr) ips.v6)
    ) addresses);
in {
  config = mkIf (confMachine.osNode != null) {
    vpsadmin.nodectld = {
      nodeId = cfg.node.id;
      consoleHost = mkDefault confMachine.addresses.primary.address;
      netInterfaces = mkDefault (lib.attrNames cfg.osNode.networking.interfaces.addresses);
    };

    services.udev.extraRules = confLib.mkNetUdevRules cfg.osNode.networking.interfaces.names;
    services.rsyslogd.hostName = "${confMachine.name}.${confMachine.host.location}";

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
  };
}
