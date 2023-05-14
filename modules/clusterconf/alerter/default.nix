{ pkgs, lib, confLib, config, confData, confMachine, ... }:
with lib;
let
  cfg = config.clusterconf.alerter;

  apuPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/machines/prg/apu";
  };

  apuBrq = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/machines/brq/apu";
  };

  alertmanagerPort = confMachine.services.alertmanager.port;

  allMachines = confLib.getClusterMachines config.cluster;

  allMonitors = filter (m: m.config.monitoring.isMonitor) allMachines;

  allContainers = filter (m: m.config.container != null) allMachines;

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
    networking = {
      firewall.extraCommands = concatStringsSep "\n" (
        (map (machine:
          ''
            # Allow access to alertmanager from monitor on ${machine.name}
            iptables -A nixos-fw -p tcp --dport ${toString alertmanagerPort} -s ${machine.config.addresses.primary.address} -j nixos-fw-accept
          ''
          ) allMonitors)
        ++
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
          smtp_smarthost = "mx1.vpsfree.cz:25";
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
                url = "http://127.0.0.1:5000/alert";
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

    # SMS alerts are primarily sent through sachet on apu.{brq, prg} equipped
    # with SIM cards. Should those be unreachable, fall back to a local sachet
    # connected to nexmo.
    services.haproxy = {
      enable = true;
      config = ''
        global
          log stdout format short daemon
          maxconn     4000

        defaults
          mode                    http
          log                     global
          option                  httplog
          option                  dontlognull
          option http-server-close
          option forwardfor       except 127.0.0.0/8
          option                  redispatch
          retries                 3
          timeout http-request    10s
          timeout queue           1m
          timeout connect         10s
          timeout client          1m
          timeout server          1m
          timeout http-keep-alive 10s
          timeout check           10s
          maxconn                 3000

        frontend api-prod
          bind 127.0.0.1:5000
          default_backend app-sachet

        backend app-sachet
          balance first
          server apu-prg ${apuPrg.services.sachet.address}:${toString apuPrg.services.sachet.port} check maxconn 32
          server apu-brq ${apuBrq.services.sachet.address}:${toString apuBrq.services.sachet.port} check maxconn 32
          server nexmo 127.0.0.1:${toString config.services.sachet.port} check maxconn 32
      '';
    };

    services.sachet = {
      enable = true;
      configPath = "/private/sachet/config.yml";
    };
  };
}
