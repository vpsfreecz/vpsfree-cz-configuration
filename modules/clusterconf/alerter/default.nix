{ pkgs, lib, confLib, config, confData, confMachine, ... }:
with lib;
let
  cfg = config.clusterconf.alerter;

  alertmanagerPort = confMachine.services.alertmanager.port;

  allContainers = filter (
    m: m.config.container != null
  ) (confLib.getClusterMachines config.cluster);

  containerInhibitRules = map (ct:
    let
      ctData = confData.vpsadmin.containers.${ct.config.host.fqdn};
    in {
      target_match = {
        fqdn = "${ct.config.host.fqdn}";
      };
      source_match_re = {
        alertname = "NodeDown|HypervisorBooting";
        fqdn = "${ctData.node.fqdn}";
      };
    }
  ) allContainers;

  intervalRoutes = [
    {
      match = {
        frequency = "weekly";
      };
      repeat_interval = "7d";
    }
    {
      match = {
        frequency = "3d";
      };
      repeat_interval = "3d";
    }
    {
      match = {
        frequency = "2d";
      };
      repeat_interval = "2d";
    }
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
  options = {
    clusterconf.alerter = {
      enable = mkEnableOption "Enable alertmanager";

      externalUrl = mkOption {
        type = types.str;
        example = "https://alerts.prg.vpsfree.cz/";
      };

      allowedMachines = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          List of confctl machine names that are allowed to access this monitor
          internally
        '';
      };

      clusterPeers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          List of confctl machine names that are added as --cluster.peer for HA
          setup
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = import ../../../overlays;

    networking = {
      firewall.extraCommands = concatStringsSep "\n" (
        (map (machine:
          let
            m = confLib.findConfig {
              cluster = config.cluster;
              name = machine;
            };
          in ''
            # Allow access to alertmanager from ${machine}
            iptables -A nixos-fw -p tcp --dport ${toString alertmanagerPort} -s ${m.addresses.primary.address} -j nixos-fw-accept
          ''
          ) cfg.allowedMachines)
        ++
        (map (machine:
          let
            m = confLib.findConfig {
              cluster = config.cluster;
              name = machine;
            };
          in ''
            # Allow access to alertmanager cluster from ${machine}
            iptables -A nixos-fw -p tcp --dport 9094 -s ${m.addresses.primary.address} -j nixos-fw-accept
          ''
          ) cfg.clusterPeers)
        );
    };

    services.prometheus.alertmanager = {
      enable = true;
      extraFlags = map (machine:
        let
          m = confLib.findConfig {
            cluster = config.cluster;
            name = machine;
          };
        in "--cluster.peer ${m.addresses.primary.address}:9094"
      ) (filter (v: v != confMachine.name) cfg.clusterPeers);
      port = alertmanagerPort;
      webExternalUrl = cfg.externalUrl;
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
                to = "aither@havefun.cz,snajpa@snajpa.net,martin@martinmyska.cz,monitoring@kerrycze.net";
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
  };
}
