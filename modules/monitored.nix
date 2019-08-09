{ lib, config, pkgs, deploymentInfo, ... }:
let
  monitoringIPs = [
    "172.16.4.10"
  ];
in
{
  networking.firewall.extraCommands = lib.concatStringsSep "\n" (map (ip:
    "iptables -A nixos-fw -p tcp -m tcp -s ${ip} --dport 9100 -j nixos-fw-accept"
  ) monitoringIPs);

  services.prometheus.exporters =
  {
    node =
    {
      enable = true;
      extraFlags = [ "--collector.textfile.directory=/run/metrics" ];
      enabledCollectors = [
        "vmstat"
        "interrupts"
        "textfile"
        "processes"
      ] ++ (lib.optionals (deploymentInfo.spin == "nixos") [ "systemd" "logind" ])
        ++ (lib.optionals (!config.boot.isContainer) [ "hwmon" "mdadm" "ksmd" ]);
    };
  };
}
