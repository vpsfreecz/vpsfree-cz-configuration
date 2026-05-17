{
  config,
  lib,
  pkgs,
  confLib,
  confData,
  confMachine,
  ...
}:
let
  inherit (lib) concatMapStringsSep filter;

  formatNetworks = list: map (net: "${net.address}/${toString net.prefix}") list;

  containerV4Networks = formatNetworks confData.vpsadmin.networks.containers.ipv4;

  containerV6Networks = formatNetworks confData.vpsadmin.networks.containers.ipv6;

  managementV4Networks = formatNetworks confData.vpsadmin.networks.management.ipv4;

  v4Networks = [
    "172.16.0.0/12"
  ]
  ++ managementV4Networks
  ++ containerV4Networks;

  v6Networks = containerV6Networks;

  allNetworks = v4Networks ++ v6Networks;

  resolverNetworks = [
    "127.0.0.0/8"
    "::1/128"
  ]
  ++ allNetworks;

  cacheTmpfsSizeM = 2048;

  cacheSizeMaxM = cacheTmpfsSizeM - 10;

  managementPort = confMachine.services.kresd-management.port;

  allMachines = confLib.getClusterMachines config.cluster;

  monitors = filter (m: m.metaConfig.monitoring.isMonitor) allMachines;

  listenAddresses = [
    "127.0.0.1"
    "::1"
  ]
  ++ map (addr: addr.address) confMachine.addresses.v4
  ++ map (addr: addr.address) confMachine.addresses.v6;
in
{
  environment.systemPackages = with pkgs; [
    dnsutils
  ];

  fileSystems."/var/cache/knot-resolver" = {
    fsType = "tmpfs";
    device = "tmpfs";
    options = [
      "rw,size=${toString cacheTmpfsSizeM}M,uid=knot-resolver,gid=knot-resolver,nosuid,nodev,noexec,mode=0700"
    ];
  };

  services.knot-resolver = {
    enable = true;
    settings = {
      workers = 8;
      network.listen = [
        {
          interface = listenAddresses;
          port = confMachine.services.kresd-plain.port;
          kind = "dns";
          freebind = true;
        }
      ];
      management.interface = "${confMachine.addresses.primary.address}@${toString managementPort}";
      cache = {
        storage = "/var/cache/knot-resolver";
        size-max = "${toString cacheSizeMaxM}M";
      };
      monitoring.metrics = "always";
      views = [
        {
          subnets = resolverNetworks;
          answer = "allow";
        }
        {
          subnets = [
            "0.0.0.0/0"
            "::/0"
          ];
          answer = "refused";
        }
      ];
    };
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
      # knot-resolver prometheus metrics ${m.name}
      iptables -A nixos-fw -p tcp --dport ${toString managementPort} -s ${m.metaConfig.addresses.primary.address} -j nixos-fw-accept
    '') monitors);
}
