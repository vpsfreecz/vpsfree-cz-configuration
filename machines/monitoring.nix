{ pkgs, lib, config, ... }:
{
  networking = {
    firewall.allowedTCPPorts = [
      3000  # grafana
      9090  # prometheus
    ];
  };

  services = {
    prometheus2 = {
      enable = true;
      extraFlags = [
        "-storage.tsdb.retention.time 365d"
        "-storage.tsdb.retention.size 200GB"
      ];
      scrapeConfigs = [
        {
          job_name = "node";
          scrape_interval = "10s";
          static_configs = [
            # mon nodes
            {
              targets = [
                "localhost:9100"
              ];
              labels = {
                alias = "mon0.vpsfree.cz";
              };
            }
            {
              targets = [
                "mon0.base48.cz:9100"
              ];
              labels = {
                alias = "mon0.base48.cz";
              };
            }
            # netboots
            {
              targets = [
                "boot.vpsadminos.org:9100"
              ];
              labels = {
                alias = "boot.vpsadminos.org";
              };
            }
            {
              targets = [
                "pxe.base48.cz:9100"
              ];
              labels = {
                alias = "pxe.base48.cz";
              };
            }

            # vpsadminos nodes
            {
              targets = [
                "devnode1.base48.cz:9100"
              ];
              labels = {
                alias = "devnode1";
              };
            }
            {
              targets = [
                "node1.stg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node1.stg";
              };
            }

            # misc
            {
              targets = [
                "fox.base48.cz:9100"
              ];
              labels = {
                alias = "fox.base48.cz";
              };
            }
          ];
        }
      ];
    };
    grafana = {
      enable = true;
      addr = "0.0.0.0";
      domain = "grafana.vpsfree.cz";
      rootUrl = "http://grafana.vpsfree.cz/";
    };
  };
}
