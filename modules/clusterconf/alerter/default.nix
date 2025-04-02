{ pkgs, lib, confLib, config, confData, confMachine, ... }:
with lib;
let
  cfg = config.clusterconf.alerter;

  apuPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/machines/prg/apu";
  };

  apuBrq = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/machines/brq/apu";
  };

  alertmanagerPort = confMachine.services.alertmanager.port;

  allMachines = confLib.getClusterMachines config.cluster;

  allMonitors = filter (m: m.metaConfig.monitoring.isMonitor) allMachines;

  allContainers = filter (m: m.metaConfig.container != null) allMachines;

  containerInhibitRules = map (ct:
    let
      ctData = confData.vpsadmin.containers.${ct.metaConfig.host.fqdn};
    in {
      target_match = {
        fqdn = "${ct.metaConfig.host.fqdn}";
      };
      source_match_re = {
        alertname = "NodeDownCritical|NodeDownFatal|HypervisorBooting";
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
        frequency = "12h";
      };
      repeat_interval = "12h";
    }
    {
      match = {
        frequency = "8h";
      };
      repeat_interval = "8h";
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

  telegramTemplate = pkgs.writeText "telegram.tmpl" ''
    {{ define "alert_list" }}{{ range . }}
    ---
    🪪 <b>{{ .Labels.alertname }}</b>
    {{- if eq .Labels.severity "fatal" }}
    🚨 FATAL 🚨 {{ end }}
    {{- if eq .Labels.severity "critical" }}
    ⚠️ CRITICAL ⚠️{{ end }}
    {{- if .Annotations.summary }}
    📝 {{ .Annotations.summary }}{{ end }}

    🏷 Labels:
    {{ range .Labels.SortedPairs }}  <i>{{ .Name }}</i>: <code>{{ .Value }}</code>
    {{ end }}{{ end }}
    🛠 <a href="https://mon1.prg.vpsfree.cz">mon1</a> / <a href="https://mon2.prg.vpsfree.cz">mon2</a> 💊 <a href="https://alerts1.prg.vpsfree.cz">alerts1</a> / <a href="https://alerts2.prg.vpsfree.cz">alerts2</a> 🛠
    {{ end }}

    {{ define "telegram.message" }}
    {{ if gt (len .Alerts.Firing) 0 }}
    🔥 Alerts Firing 🔥
    {{ template "alert_list" .Alerts.Firing }}
    {{ end }}
    {{ if gt (len .Alerts.Resolved) 0 }}
    ✅ Alerts Resolved ✅
    {{ template "alert_list" .Alerts.Resolved }}
    {{ end }}
    {{ end }}
  '';
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
            iptables -A nixos-fw -p tcp --dport ${toString alertmanagerPort} -s ${machine.metaConfig.addresses.primary.address} -j nixos-fw-accept
          ''
          ) allMonitors)
        ++
        (map (machine:
          let
            m = confLib.findMetaConfig {
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
            m = confLib.findMetaConfig {
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
          m = confLib.findMetaConfig {
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
        templates = [
          telegramTemplate
        ];
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

            # Telegram alerts
            {
              match_re = {
                severity = "critical|fatal";
              };
              receiver = "team-telegram";
              group_wait = "10s";
              repeat_interval = "10m";
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
                to = "aither@havefun.cz,snajpa@snajpa.net,monitoring@kerrycze.net";
                send_resolved = true;
              }
            ];
          }
          {
            name = "team-telegram";
            telegram_configs = [
              {
                bot_token_file = "/private/alertmanager/telegram_bot_token.txt";
                chat_id = -1002692367921;
                send_resolved = true;
                message = ''{{ template "telegram.message". }}'';
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
            source_match_re = {
              alertname = "NodeDownCritical|NodeDownFatal";
            };
            equal = [ "fqdn" ];
          }

          # Ignore NodeSshDown alerts when NodeDown is firing as well
          {
            target_match = {
              alertclass = "sshdown";
            };
            source_match = {
              alertclass = "nodedown";
            };
            equal = [ "fqdn" ];
          }

          # Ignore alerts with alertwhen=inuse when hypervisor is nearly empty
          {
            target_match = {
              alertwhen = "inuse";
            };
            source_match = {
              alertname = "HypervisorNearlyEmpty";
            };
            equal = [ "fqdn" ];
          }

          # Ignore fatal alerts when hypervisor is completely empty
          {
            target_match = {
              severity = "fatal";
            };
            source_match = {
              alertname = "HypervisorEmpty";
            };
            equal = [ "fqdn" ];
          }

          # Ignore LxcStartFailed when a more concrete alert is firing
          {
            target_match = {
              alertname = "LxcStartFailed";
            };
            source_match = {
              alertclass = "lxcstartfail";
            };
            equal = [ "fqdn" "id" ];
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
