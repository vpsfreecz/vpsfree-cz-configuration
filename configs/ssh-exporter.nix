{ config, lib, confLib, ... }:
with lib;
let
  allMachines = confLib.getClusterMachines config.cluster;

  allNodes = filter (m: m.metaConfig.node != null && m.metaConfig.monitoring.enable) allMachines;

  monitors = filter (m: m.metaConfig.monitoring.isMonitor) allMachines;

  getAlias = host: "${host.name}${optionalString (!isNull host.location) ".${host.location}"}";

  hosts = listToAttrs (map (m: nameValuePair m.name {
    alias = getAlias m.metaConfig.host;
    fqdn = m.metaConfig.host.fqdn;
    user = "ssh-check";
    private_key_file = "/secrets/ssh-exporter/id_ecdsa";
    timeout = 45;
  }) allNodes);

  port = config.serviceDefinitions.ssh-exporter.port;
in {
  services.prometheus.confExporters.ssh = {
    enable = true;
    port = port;
    settings.hosts = hosts;
  };

  networking.firewall.extraCommands = concatMapStringsSep "\n" (m: ''
    # ssh-exporter from ${m.name}
    iptables -A nixos-fw -p tcp --dport ${toString port} -s ${m.metaConfig.addresses.primary.address} -j nixos-fw-accept
  '') monitors;
}
