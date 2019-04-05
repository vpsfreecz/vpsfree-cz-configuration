{ pkgs, lib, config, ... }:
{
  networking = {
    firewall.allowedTCPPorts = [
      3000  # grafana
      9090  # prometheus
    ];
  };

  services = {
    prometheus = {
      enable = true;
      extraFlags = [
        "-storage.local.retention 8760h"  # 365 days
        "-storage.local.series-file-shrink-ratio 0.3"
        "-storage.local.memory-chunks 2097152"
        "-storage.local.max-chunks-to-persist 1048576"
        "-storage.local.index-cache-size.fingerprint-to-metric 2097152"
        "-storage.local.index-cache-size.fingerprint-to-timerange 1048576"
        "-storage.local.index-cache-size.label-name-to-label-values 2097152"
        "-storage.local.index-cache-size.label-pair-to-fingerprints 41943040"
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
