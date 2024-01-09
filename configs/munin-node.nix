{ config, lib, confLib, ... }:
let
  inherit (lib) concatMapStringsSep filter flatten hasAttr replaceStrings;

  allMachines = confLib.getClusterMachines config.cluster;

  muninCrons = filter (m: hasAttr "munin-cron" m.config.services) allMachines;

  disabledNetifPlugins = flatten (map (v: [ "if_${v}" "if_err_${v}" ]) [
    "dummy*"
    "eth*"
    "ifb*"
    "osrtr*"
    "veth*"
    "erspan*"
    "gretap*"
    "tun*"
    "virtip"
  ]);
in {
  services.munin-node = {
    enable = true;
    disabledPlugins = [
      "df"
      "df_abs"
      "df_inode"
      "meminfo"
      "munin_stats"
      "port_*"
      "swap"
    ] ++ disabledNetifPlugins;
    extraConfig = concatMapStringsSep "\n\n" (m: ''
      # Allow access from ${m.config.host.fqdn}
      allow ^${replaceStrings ["."] ["\\."] m.config.addresses.primary.address}$
    '') muninCrons;
  };

  networking.firewall.extraCommands = concatMapStringsSep "\n\n" (m: ''
    # Allow access to munin-node from ${m.config.host.fqdn}
    iptables -A nixos-fw -p tcp --dport 4949 -s ${m.config.addresses.primary.address} -j nixos-fw-accept
  '') muninCrons;
}
