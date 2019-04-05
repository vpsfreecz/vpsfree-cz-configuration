{ lib, config, pkgs, ... }:
let
  # this needs to be a list of IPs
  monitoringIP = "172.17.66.66";
in
{
  # XXX: FROM EVERYWHERE FOR NOW
  networking.firewall.allowedTCPPorts = [ 9100 ];

  services.prometheus.exporters =
  {
    node =
    {
      enable = true;
      firewallFilter = "-s ${monitoringIP} -p tcp -m tcp --dport 9100";
      extraFlags = [ "--collector.textfile.directory=/run/metrics" ];
      enabledCollectors = [
        "vmstat"
        "systemd"
        "logind"
        "interrupts"
        "textfile"
        "processes"
      ] ++ lib.optionals (!config.boot.isContainer) [ "hwmon" "mdadm" "ksmd" ];
    };
  };
}
