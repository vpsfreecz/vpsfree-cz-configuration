{ pkgs, lib, config, ... }:
{
  imports = [
    ../modules/monitored.nix
  ];

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
          job_name = "mon";
          scrape_interval = "60s";
          static_configs = [
            {
              targets = [
                "localhost:9090"
              ];
              labels = {
                alias = "mon0.vpsfree.cz";
              };
            }
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
                "mon0.base48.cz:9090"
              ];
              labels = {
                alias = "mon0.base48.cz";
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
          ];
        }
        {
          job_name = "pxe";
          scrape_interval = "60s";
          static_configs = [
            {
              targets = [
                "pxe.vpsfree.cz:9100"
              ];
              labels = {
                alias = "pxe.vpsfree.cz";
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
          ];
        }
        {
          job_name = "nodes";
          scrape_interval = "60s";
          static_configs = [
            {
              targets = [
                "backuper.prg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "backuper";
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
            {
              targets = [
                "node2.stg.vpsfree.cz:9100"
              ];
              labels = {
                alias = "node2.stg";
              };
            }
            {
              targets = [
                "devnode1.base48.cz:9100"
              ];
              labels = {
                alias = "devnode1";
              };
            }
          ];
        }
        {
          job_name = "infra";
          scrape_interval = "60s";
          static_configs = [
            {
              targets = [
                "build.vpsfree.cz:9100"
              ];
              labels = {
                alias = "build";
              };
            }
            {
              targets = [
                "vpsadminos.org:9100"
              ];
              labels = {
                alias = "vpsadminos.org";
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
