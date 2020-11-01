{ pkgs, lib, confLib, config, confData, deploymentInfo, ... }:
with lib;
let
  monPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "cz.vpsfree";
    location = "prg";
    name = "int.mon";
  };

  logPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "cz.vpsfree";
    location = "prg";
    name = "log";
  };

  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "cz.vpsfree";
    location = "prg";
    name = "proxy";
  };

  alertmanagerPort = deploymentInfo.config.services.alertmanager.port;

  allContainers = filter (
    d: d.type == "container"
  ) (confLib.getClusterDeployments config.cluster);

  containerInhibitRules = map (ct:
    let
      realLocation = if isNull ct.location then "global" else ct.location;
      ctData = confData.vpsadmin.containers.${ct.domain}.${realLocation}.${ct.name};
    in {
      target_match = {
        type = "container";
        fqdn = "${ct.fqdn}";
      };
      source_match_re = {
        alertname = "NodeDown|HypervisorBooting";
        type = "node";
        fqdn = "${ctData.node.fqdn}";
      };
    }
  ) allContainers;

  intervalRoutes = [
    {
      match = {
        frequency = "daily";
      };
      repeat_interval = "24h";
    }
    {
      match = {
        frequency = "6h";
      };
      repeat_interval = "6h";
    }
    {
      match = {
        frequency = "hourly";
      };
      repeat_interval = "1h";
    }
    {
      match = {
        frequency = "15m";
      };
      repeat_interval = "15m";
    }
    {
      match = {
        frequency = "10m";
      };
      repeat_interval = "10m";
    }
    {
      match = {
        frequency = "5m";
      };
      repeat_interval = "5m";
    }
    {
      match = {
        frequency = "2m";
      };
      repeat_interval = "2m";
    }
    {
      match_re = {
        frequency = "1m|minutely";
      };
      repeat_interval = "1m";
    }
    {
      match = {
        frequency = "15s";
      };
      repeat_interval = "15s";
    }
  ];
in {
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
  ];

  nixpkgs.overlays = import ../../../../../overlays;

  networking = {
    firewall.extraCommands = ''
      # Allow access to alertmanager from prometheus
      iptables -A nixos-fw -p tcp --dport ${toString alertmanagerPort} -s ${monPrg.addresses.primary.address} -j nixos-fw-accept

      # Allow access to alertmanager from log.prg
      iptables -A nixos-fw -p tcp --dport ${toString alertmanagerPort} -s ${logPrg.addresses.primary.address} -j nixos-fw-accept

      # Allow access to alertmanager from proxy.prg
      iptables -A nixos-fw -p tcp --dport ${toString alertmanagerPort} -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept
    '';
  };

  services.prometheus.alertmanager = {
    enable = true;
    port = alertmanagerPort;
    webExternalUrl = "https://alerts.prg.vpsfree.cz/";
    configuration = {
      global = {
        smtp_smarthost = "localhost:25";
        smtp_from = "alertmanager@vpsfree.cz";
        smtp_require_tls = false;
      };
      route = {
        group_by = [ "alertname" "alias" ];
        group_wait = "30s";
        group_interval = "2m";
        repeat_interval = "4h";
        receiver = "team-mail";

        routes = [
          # Mail alerts
          {
            match_re = {
              severity = "warning|critical|fatal";
            };
            group_wait = "30s";
            group_interval = "2m";
            repeat_interval = "4h";
            receiver = "team-mail";
            continue = true;

            routes = intervalRoutes;
          }

          # SMS alerts
          {
            match_re = {
              severity = "critical|fatal";
            };
            receiver = "team-sms";
            group_wait = "10s";
            repeat_interval = "10m";
            continue = false;

            routes = intervalRoutes;
          }

          # Blackhole
          {
            match = {
              severity = "none";
            };
            receiver = "blackhole";
            continue = false;
          }
        ];
      };
      receivers = [
        {
          name = "team-mail";
          email_configs = [
            {
              to = "aither@havefun.cz,snajpa@snajpa.net";
              send_resolved = true;
            }
          ];
        }
        {
          name = "team-sms";
          webhook_configs = [
            {
              url = "http://localhost:9876/alert";
              send_resolved = true;
            }
          ];
        }
        {
          name = "blackhole";
        }
      ];

      inhibit_rules = [
        # Ignore unreachable exporters when nodes are down
        {
          target_match = {
            alertname = "NodeExporterDown";
          };
          source_match = {
            alertname = "NodeDown";
          };
          equal = [ "fqdn" ];
        }

        # Disable less-important alerts when more important alerts of the same
        # class are firing.
        {
          target_match = {
            severity = "critical";
          };
          target_match_re = {
            alertclass = ".+";
          };
          source_match = {
            severity = "fatal";
          };
          equal = [ "alertclass" "instance" ];
        }
        {
          target_match = {
            severity = "warning";
          };
          target_match_re = {
            alertclass = ".+";
          };
          source_match = {
            severity = "critical";
          };
          equal = [ "alertclass" "instance" ];
        }

        # Disable critical alerts during quiet hours. Use fatal alerts to bypass
        # quiet hours.
        {
          target_match = {
            severity = "critical";
          };
          source_match = {
            alertname = "QuietHours";
          };
        }

        # Ignore alerts for containers which are on nodes that are down or booting
      ] ++ containerInhibitRules;
    };
  };

  services.postfix.enable = true;

  services.sachet = {
    enable = true;
    configPath = "/private/sachet/config.yml";
  };
}
