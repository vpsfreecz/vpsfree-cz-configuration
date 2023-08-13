{ config, lib, confLib, ... }:
with lib;
let
  allMachines = confLib.getClusterMachines config.cluster;

  allNodes = filter (m: m.config.node != null && m.config.monitoring.enable) allMachines;

  monitors = filter (m: m.config.monitoring.isMonitor) allMachines;

  getAlias = host: "${host.name}${optionalString (!isNull host.location) ".${host.location}"}";

  hosts = listToAttrs (map (m: nameValuePair m.name {
    alias = getAlias m.config.host;
    fqdn = m.config.host.fqdn;
    user = "ssh-check";
    private_key_file = "/secrets/ssh-exporter/id_ecdsa";
  }) allNodes);

  port = config.serviceDefinitions.ssh-exporter.port;
in {
  services.ssh-exporter = {
    enable = true;
    port = port;
    settings.hosts = hosts;
  };

  networking.firewall.extraCommands = concatMapStringsSep "\n" (m: ''
    # ssh-exporter from ${m.name}
    iptables -A nixos-fw -p tcp --dport ${toString port} -s ${m.config.addresses.primary.address} -j nixos-fw-accept
  '') monitors;
}
