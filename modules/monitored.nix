{ lib, config, pkgs, deploymentInfo, ... }:
let
  monitoringIPs = [
    "172.16.4.10"
    "172.17.66.66"
  ];
in
{
  networking.firewall.allowedTCPPorts = [ 9100 ];
  networking.firewall.extraCommands = lib.concatStringsSep "\n" (
    lib.flip map monitoringIPs (ip: "iptables -A INPUT -p tcp -m tcp -s ${ip} --dport 9100 -j ACCEPT"));

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
