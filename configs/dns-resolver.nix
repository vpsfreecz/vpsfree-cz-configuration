{ config, lib, pkgs, confLib, confData, confMachine, ... }:
let
  inherit (lib) concatMapStringsSep filter optionals;

  formatNetworks = list: map (net: "${net.address}/${toString net.prefix}") list;

  containerV4Networks = formatNetworks confData.vpsadmin.networks.containers.ipv4;

  containerV6Networks = formatNetworks confData.vpsadmin.networks.containers.ipv6;

  managementV4Networks = formatNetworks confData.vpsadmin.networks.management.ipv4;

  v4Networks = [
    "172.16.0.0/12"
  ] ++ managementV4Networks
    ++ containerV4Networks
    ++ (optionals (confMachine.host.location == "brq") [
      # NAT in prg, needed in brq for access from monitoring
      "83.167.228.130/32"
      "81.31.40.98/32"
      "81.31.40.102/32"
    ]);

  v6Networks = containerV6Networks;

  allNetworks = v4Networks ++ v6Networks;

  unboundNetworks = [ "127.0.0.0/8" "::1/128" ] ++ allNetworks;

  exporterPort = confMachine.services.unbound-exporter.port;

  allMachines = confLib.getClusterMachines config.cluster;

  monitors = filter (m: m.config.monitoring.isMonitor) allMachines;

  numThreads = 8;
in {
  environment.systemPackages = with pkgs; [
    dnsutils
  ];

  services.unbound = {
    enable = true;
    settings = {
      server = {
        # Optimizations based on https://nlnetlabs.nl/documentation/unbound/howto-optimise/
        num-threads = numThreads;
        msg-cache-slabs = numThreads;
        rrset-cache-slabs = numThreads;
        infra-cache-slabs = numThreads;
        key-cache-slabs = numThreads;

        rrset-cache-size = "100m";
        msg-cache-size = "50m";

        so-reuseport = true;

        interface = [ "0.0.0.0" "::0" ];
        access-control = map (net: "${net} allow") unboundNetworks;

        harden-glue = true;
        harden-dnssec-stripped = true;
        harden-below-nxdomain = true;
        harden-referral-path = true;

        prefetch = true;
        prefetch-key = true;

        use-caps-for-id = false;
        unwanted-reply-threshold = 10000000;

        rrset-roundrobin = true;
        minimal-responses = false;
      };
      remote-control = {
        control-enable = true;
      };
    };
  };

  services.prometheus.exporters.unbound = {
    enable = true;
    port = exporterPort;
  };

  networking.firewall.extraCommands =
    (concatMapStringsSep "\n" (net: ''
      iptables -A nixos-fw -p udp -s ${net} --dport 53 -j nixos-fw-accept
      iptables -A nixos-fw -p tcp -s ${net} --dport 53 -j nixos-fw-accept
    '') v4Networks)
    + (concatMapStringsSep "\n" (net: ''
      ip6tables -A nixos-fw -p udp -s ${net} --dport 53 -j nixos-fw-accept
      ip6tables -A nixos-fw -p tcp -s ${net} --dport 53 -j nixos-fw-accept
    '') v6Networks)
    + (concatMapStringsSep "\n" (m: ''
      # unbound-exporter from ${m.name}
      iptables -A nixos-fw -p tcp --dport ${toString exporterPort} -s ${m.config.addresses.primary.address} -j nixos-fw-accept
    '') monitors);
}
