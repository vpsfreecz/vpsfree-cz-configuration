{ config, lib, ... }:
let
  disabledNetifPlugins = lib.flatten (map (v: [ "if_${v}" "if_err_${v}" ]) [
    "dummy*"
    "eth*"
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
      "munin_stats"
      "port_*"
      "swap"
    ] ++ disabledNetifPlugins;
    extraConfig = ''
      # Allow access from prasiatko.int
      allow ^83\.167\.228\.42$
      allow ^172\.16\.8\.234$
    '';
  };

  networking.firewall.extraCommands = ''
    # Allow access to munin-node from prasiatko.int
    iptables -A nixos-fw -p tcp --dport 4949 -s 83.167.228.42 -j nixos-fw-accept
    iptables -A nixos-fw -p tcp --dport 4949 -s 172.16.8.234 -j nixos-fw-accept
  '';
}
