{ pkgs, lib, confData, confLib, config, confMachine, ... }:
with lib;
let
  cfg = config.clusterconf.monitor;

  promPort = confMachine.services.prometheus.port;
  exporterPort = confMachine.services.node-exporter.port;

  allMachines = confLib.getClusterMachines config.cluster;

  monitoredMachines = filter (m: m.config.monitoring.enable) allMachines;

  getAlias = host: "${host.name}${optionalString (!isNull host.location) ".${host.location}"}";
  ensureLocation = location: if location == null then "global" else location;

  filterServices = machine: fn:
    let
      serviceList = mapAttrsToList (name: config: {
        inherit machine name config;
      }) machine.config.services;
    in
      filter (sv: fn sv.config) serviceList;

  scrapeConfigs = {
    monitorings =
      let
        machines = filter (m:
          m.config.monitoring.isMonitor && m.config.host.fqdn != confMachine.host.fqdn
        ) monitoredMachines;
      in {
        exporterConfigs = [
          {
            targets = [
              "localhost:${toString promPort}"
              "localhost:${toString exporterPort}"
            ];
            labels = {
              alias = getAlias confMachine.host;
              fqdn = confMachine.host.fqdn;
            } // confMachine.monitoring.labels;
          }
        ] ++ (flatten (map (m: {
          targets = [
            "${m.config.host.fqdn}:${toString m.services.prometheus.port}"
            "${m.config.host.fqdn}:${toString m.services.node-exporter.port}"
          ];
          labels = {
            alias = getAlias m.config.host;
            fqdn = m.config.host.fqdn;
          } // m.config.monitoring.labels;
        }) machines));

        pingConfigs = map (m: {
          targets = [ m.config.host.fqdn ];
          labels = {
            alias = getAlias m.config.host;
            fqdn = m.config.host.fqdn;
            domain = m.config.host.domain;
            location = realLocation m.config.host.location;
            os = m.config.spin;
          };
        }) machines;
      };

    infra =
      let
        machines = filter (m:
          !m.config.monitoring.isMonitor && (m.config.node == null)
        ) monitoredMachines;

        exporterMachines = filter (m: m.config.spin != "other") machines;
      in {
        exporterConfigs = map (m: {
          targets = [
            "${m.config.host.fqdn}:${toString m.config.services.node-exporter.port}"
          ] ++ (optional (hasAttr "osctl-exporter" m.config.services) "${m.config.host.fqdn}:${toString m.config.services.osctl-exporter.port}");
          labels = {
            alias = getAlias m.config.host;
            fqdn = m.config.host.fqdn;
            domain = m.config.host.domain;
            location = ensureLocation m.config.host.location;
            os = m.config.spin;
          } // m.config.monitoring.labels;
        }) exporterMachines;

        pingConfigs = map (m: {
          targets = [ m.config.host.fqdn ];
          labels = {
            alias = getAlias m.config.host;
            fqdn = m.config.host.fqdn;
            domain = m.config.host.domain;
            location = ensureLocation m.config.host.location;
            os = m.config.spin;
          };
        }) machines;
      };

    nodes =
      let
        machines = filter (m: m.config.node != null) monitoredMachines;
      in {
        exporterConfigs = map (m: {
          targets = [
            "${m.config.host.fqdn}:${toString m.config.services.node-exporter.port}"
          ] ++ (optional (hasAttr "osctl-exporter" m.config.services) "${m.config.host.fqdn}:${toString m.config.services.osctl-exporter.port}");
          labels = {
            alias = getAlias m.config.host;
            fqdn = m.config.host.fqdn;
            domain = m.config.host.domain;
            location = ensureLocation m.config.host.location;
            type = "node";
            os = m.config.spin;
            role = m.config.node.role;
          } // m.config.monitoring.labels;
        }) machines;

        pingConfigs = map (m: {
          targets = [ m.config.host.fqdn ];
          labels = {
            alias = getAlias m.config.host;
            fqdn = m.config.host.fqdn;
            domain = m.config.host.domain;
            location = ensureLocation m.config.host.location;
            role = m.config.node.role;
            os = m.config.spin;
          };
        }) machines;
      };

    dnsResolvers =
      let
        resolverServices = flatten (map (m:
          filterServices m (sv: sv.monitor == "dns-resolver")
        ) monitoredMachines);
      in {
        dnsProbes = map (sv: {
          targets = [ "${sv.config.address}:${toString sv.config.port}" ];
          labels = {
            fqdn = sv.machine.config.host.fqdn;
            domain = sv.machine.config.host.domain;
            location = ensureLocation sv.machine.config.host.location;
            service = "dns-resolver";
          };
        }) resolverServices;
      };

    dnsAuthoritatives =
      let
        authoritativeServices = flatten (map (m:
          filterServices m (sv: sv.monitor == "dns-authoritative")
        ) monitoredMachines);
      in {
        dnsProbes = map (sv: {
          targets = [ "${sv.config.address}:${toString sv.config.port}" ];
          labels = {
            fqdn = sv.machine.config.host.fqdn;
            domain = sv.machine.config.host.domain;
            location = ensureLocation sv.machine.config.host.location;
            service = "dns-authoritative";
          };
        }) authoritativeServices;
      };

    jitsiMeet = {
      jvbConfigs = flatten (mapAttrsToList (project: conf:
        mapAttrsToList (name: addr: {
          targets = [ "${addr}:9100" ];
          labels = {
            alias = "meet-${name}";
            type = "meet-jvb";
            project = project;
          };
        }) conf.videoBridges) confData.meet);

      jvbPingConfigs = flatten (mapAttrsToList (project: conf:
        mapAttrsToList (name: addr: {
          targets = [ addr ];
          labels = {
            alias = "meet-${name}";
            type = "meet-jvb";
            project = project;
          };
        }) conf.videoBridges) confData.meet);

      webConfigs = mapAttrs (project: conf: {
        targets = [ conf.url ];
        labels = {
          alias = conf.alias;
          type = "meet-web";
        };
      }) confData.meet;
    };
  };
in {
  options = {
    clusterconf.monitor = {
      enable = mkEnableOption "Enable prometheus server";

      retention.time = mkOption {
        type = types.str;
        default = "365d";
      };

      retention.size = mkOption {
        type = types.str;
        default = "100GB";
      };

      alerters = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          List of confctl machine names with configured alertmanager
        '';
      };

      externalUrl = mkOption {
        type = types.str;
        example = "https://mon.prg.vpsfree.cz/";
      };

      allowedMachines = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          List of confctl machine names that are allowed to access this monitor
          internally
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    networking = {
      firewall.extraCommands = concatMapStringsSep "\n" (machine:
        let
          m = confLib.findConfig {
            cluster = config.cluster;
            name = machine;
          };
        in ''
          # Allow access to prometheus from ${machine}
          iptables -A nixos-fw -p tcp --dport ${toString promPort} -s ${m.addresses.primary.address} -j nixos-fw-accept
        ''
      ) cfg.allowedMachines;
    };

    services = {
      prometheus = {
        enable = true;
        extraFlags = [
          "--storage.tsdb.retention.time ${cfg.retention.time}"
          "--storage.tsdb.retention.size ${cfg.retention.size}"
        ];
        listenAddress = "0.0.0.0";
        port = promPort;
        webExternalUrl = "${cfg.externalUrl}";
        scrapeConfigs = [
          {
            job_name = "mon";
            scrape_interval = "60s";
            static_configs = scrapeConfigs.monitorings.exporterConfigs;
          }
        ] ++ (optional (scrapeConfigs.monitorings.pingConfigs != [])
          {
            job_name = "mon-ping";
            scrape_interval = "15s";
            metrics_path = "/probe";
            params = {
              module = [ "icmp" ];
            };
            static_configs = scrapeConfigs.monitorings.pingConfigs;
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }
        ) ++ [
          {
            job_name = "nodes";
            scrape_interval = "30s";
            static_configs = scrapeConfigs.nodes.exporterConfigs;
          }
        ] ++ (optional (scrapeConfigs.nodes.pingConfigs != [])
          {
            job_name = "nodes-ping";
            scrape_interval = "15s";
            metrics_path = "/probe";
            params = {
              module = [ "icmp" ];
            };
            static_configs = scrapeConfigs.nodes.pingConfigs;
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }
        ) ++ [
          {
            job_name = "infra";
            scrape_interval = "60s";
            static_configs = scrapeConfigs.infra.exporterConfigs;
          }
        ] ++ (optional (scrapeConfigs.infra.pingConfigs != [])
          {
            job_name = "infra-ping";
            scrape_interval = "15s";
            metrics_path = "/probe";
            params = {
              module = [ "icmp" ];
            };
            static_configs = scrapeConfigs.infra.pingConfigs;
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }
        ) ++ (optional (scrapeConfigs.dnsResolvers.dnsProbes != [])
          {
            job_name = "dns-resolvers";
            scrape_interval = "60s";
            metrics_path = "/probe";
            params = {
              module = [ "dns_resolver" ];
            };
            static_configs = scrapeConfigs.dnsResolvers.dnsProbes;
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }
        ) ++ (optional (scrapeConfigs.dnsAuthoritatives.dnsProbes != [])
          {
            job_name = "dns-authoritatives";
            scrape_interval = "60s";
            metrics_path = "/probe";
            params = {
              module = [ "dns_authoritative" ];
            };
            static_configs = scrapeConfigs.dnsAuthoritatives.dnsProbes;
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }
        ) ++ [
          {
            job_name = "vpsfree-cz-web";
            scrape_interval = "300s";
            metrics_path = "/probe";
            params = {
              module = [ "vpsfree_cz_http_2xx" ];
            };
            static_configs = [
              {
                targets = [ "https://vpsfree.cz/prihlaska/fyzicka-osoba/" ];
                labels = {
                  alias = "vpsfree.cz";
                  type = "vpsfree-web";
                };
              }
            ];
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }
          {
            job_name = "vpsfree-org-web";
            scrape_interval = "300s";
            metrics_path = "/probe";
            params = {
              module = [ "vpsfree_org_http_2xx" ];
            };
            static_configs = [
              {
                targets = [ "https://vpsfree.org/registration/fyzicka-osoba/" ];
                labels = {
                  alias = "vpsfree.org";
                  type = "vpsfree-web";
                };
              }
            ];
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }
          {
            job_name = "meet-jvbs";
            scrape_interval = "30s";
            static_configs = scrapeConfigs.jitsiMeet.jvbConfigs;
          }
          {
            job_name = "meet-jvbs-ping";
            scrape_interval = "15s";
            metrics_path = "/probe";
            params = {
              module = [ "icmp" ];
            };
            static_configs = scrapeConfigs.jitsiMeet.jvbPingConfigs;
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }
        ] ++ (
          mapAttrsToList (project: conf: {
            job_name = "meet-web-${project}";
            scrape_interval = "60s";
            metrics_path = "/probe";
            params = {
              module = [ "meet_${project}_http_2xx" ];
            };
            static_configs = [
              scrapeConfigs.jitsiMeet.webConfigs.${project}
            ];
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }) confData.meet
        );

        alertmanagers = [
          {
            scheme = "http";
            static_configs = [
              {
                targets = map (machine:
                  let
                    alerter = confLib.findConfig {
                      cluster = config.cluster;
                      name = machine;
                    };
                    addr = alerter.services.alertmanager.address;
                    port = alerter.services.alertmanager.port;
                  in "${addr}:${toString port}"
                ) cfg.alerters;
              }
            ];
          }
        ];

        ruleConfigs = flatten (map (v: import v) [
          ./rules/common.nix
          ./rules/nodes.nix
          ./rules/infra.nix
          ./rules/dns.nix
          ./rules/smartmon.nix
          ./rules/time-of-day.nix
          ./rules/meet.nix
          ./rules/vpsfree-web.nix
        ]);
      };

      prometheus.exporters.blackbox =
        let
          staticModules = {
            icmp = {
              prober = "icmp";
              timeout = "5s";
              icmp.preferred_ip_protocol = "ip4";
            };
            dns_resolver = {
              prober = "dns";
              dns = {
                query_name = "google.com";
                query_type = "A";
                transport_protocol = "tcp";
              };
            };
            dns_authoritative = {
              prober = "dns";
              dns = {
                query_name = "vpsfree.cz";
                query_type = "A";
                transport_protocol = "tcp";
              };
            };
            vpsfree_cz_http_2xx = {
              prober = "http";
              timeout = "5s";
              http = {
                valid_http_versions = [ "HTTP/1.1" "HTTP/2.0" ];
                method = "GET";
                headers = {
                  Host = "vpsfree.cz";
                };
                preferred_ip_protocol = "ip4";
              };
            };
            vpsfree_org_http_2xx = {
              prober = "http";
              timeout = "5s";
              http = {
                valid_http_versions = [ "HTTP/1.1" "HTTP/2.0" ];
                method = "GET";
                headers = {
                  Host = "vpsfree.org";
                };
                preferred_ip_protocol = "ip4";
              };
            };
          };

          meetModules = mapAttrs' (project: conf:
            nameValuePair "meet_${project}_http_2xx" {
              prober = "http";
              timeout = "5s";
              http = {
                valid_http_versions = [ "HTTP/1.1" "HTTP/2.0" ];
                method = "GET";
                headers = {
                  Host = conf.host;
                };
                preferred_ip_protocol = "ip4";
              };
            }
          ) confData.meet;
        in {
          enable = true;
          listenAddress = "127.0.0.1";
          configFile = pkgs.writeText "blackbox.yml" (builtins.toJSON {
            modules = staticModules // meetModules;
          });
        };
    };
  };
}
