{ pkgs, lib, confData, confLib, config, confMachine, ... }:
with lib;
let
  cfg = config.clusterconf.monitor;

  promPort = confMachine.services.prometheus.port;
  exporterPort = confMachine.services.node-exporter.port;

  allMachines = confLib.getClusterMachines config.cluster;

  monitoredMachines =
    if isNull cfg.monitorMachines then
      filter (m: m.metaConfig.monitoring.enable && isNull m.carrier && !(isNull m.metaConfig.host.target)) allMachines
    else
      filter (m: elem m.name cfg.monitorMachines) allMachines;

  getAlias = host: "${host.name}${optionalString (!isNull host.location) ".${host.location}"}";
  ensureLocation = location: if location == null then "global" else location;

  filterServices = machine: fn:
    let
      serviceList = mapAttrsToList (name: svConfig: {
        inherit machine name svConfig;
      }) machine.metaConfig.services;
    in
      filter (sv: fn sv.svConfig) serviceList;

  scrapeConfigs = {
    monitorings =
      let
        machines = filter (m:
          m.metaConfig.monitoring.isMonitor && m.metaConfig.host.fqdn != confMachine.host.fqdn
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
            "${m.metaConfig.host.fqdn}:${toString m.metaConfig.services.node-exporter.port}"
          ];
          labels = {
            alias = getAlias m.metaConfig.host;
            fqdn = m.metaConfig.host.fqdn;
          } // m.metaConfig.monitoring.labels;
        }) machines));

        pingConfigs = map (m: {
          targets = [ m.metaConfig.host.fqdn ];
          labels = {
            alias = getAlias m.metaConfig.host;
            fqdn = m.metaConfig.host.fqdn;
            domain = m.metaConfig.host.domain;
            location = ensureLocation m.metaConfig.host.location;
            os = m.metaConfig.spin;
          };
        }) machines;
      };

    loggers =
      let
        machines = filter (m:
          m.metaConfig.logging.isLogger && m.metaConfig.host.fqdn != confMachine.host.fqdn
        ) monitoredMachines;
      in {
        exporterConfigs = map (m: {
          targets = [
            "${m.metaConfig.host.fqdn}:${toString m.metaConfig.services.syslog-exporter.port}"
          ];
          labels = {
            logger_alias = getAlias m.metaConfig.host;
            logger_fqdn = m.metaConfig.host.fqdn;
          };
        }) machines;
      };

    infra =
      let
        machines = filter (m:
          !m.metaConfig.monitoring.isMonitor && (m.metaConfig.node == null)
        ) monitoredMachines;

        exporterMachines = filter (m: m.metaConfig.spin != "other") machines;
      in {
        exporterConfigs = map (m: {
          targets = [
            "${m.metaConfig.host.fqdn}:${toString m.metaConfig.services.node-exporter.port}"
          ] ++ (optional (hasAttr "osctl-exporter" m.metaConfig.services) "${m.metaConfig.host.fqdn}:${toString m.metaConfig.services.osctl-exporter.port}");
          labels = {
            alias = getAlias m.metaConfig.host;
            fqdn = m.metaConfig.host.fqdn;
            domain = m.metaConfig.host.domain;
            location = ensureLocation m.metaConfig.host.location;
            os = m.metaConfig.spin;
          } // m.metaConfig.monitoring.labels;
        }) exporterMachines;

        pingConfigs = map (m: {
          targets = [ m.metaConfig.host.fqdn ];
          labels = {
            alias = getAlias m.metaConfig.host;
            fqdn = m.metaConfig.host.fqdn;
            domain = m.metaConfig.host.domain;
            location = ensureLocation m.metaConfig.host.location;
            os = m.metaConfig.spin;
          };
        }) machines;
      };

    nodes =
      let
        machines = filter (m: m.metaConfig.node != null) monitoredMachines;
      in {
        exporterConfigs = map (m: {
          targets = [
            "${m.metaConfig.host.fqdn}:${toString m.metaConfig.services.node-exporter.port}"
          ] ++ (optional (hasAttr "osctl-exporter" m.metaConfig.services) "${m.metaConfig.host.fqdn}:${toString m.metaConfig.services.osctl-exporter.port}")
            ++ (optional (hasAttr "ksvcmon-exporter" m.metaConfig.services) "${m.metaConfig.host.fqdn}:${toString m.metaConfig.services.ksvcmon-exporter.port}");
          labels = {
            alias = getAlias m.metaConfig.host;
            fqdn = m.metaConfig.host.fqdn;
            domain = m.metaConfig.host.domain;
            location = ensureLocation m.metaConfig.host.location;
            type = "node";
            os = m.metaConfig.spin;
            role = m.metaConfig.node.role;
            storage_type = m.metaConfig.node.storageType;
          } // m.metaConfig.monitoring.labels;
        }) machines;

        ipmiConfigs = map (m: {
          targets = [
            "${m.metaConfig.host.fqdn}:${toString m.metaConfig.services.ipmi-exporter.port}"
          ];
          labels = {
            alias = getAlias m.metaConfig.host;
            fqdn = m.metaConfig.host.fqdn;
            domain = m.metaConfig.host.domain;
            location = ensureLocation m.metaConfig.host.location;
            type = "node";
            os = m.metaConfig.spin;
            role = m.metaConfig.node.role;
            storage_type = m.metaConfig.node.storageType;
          } // m.metaConfig.monitoring.labels;
        }) machines;

        pingConfigs = map (m: {
          targets = [ m.metaConfig.host.fqdn ];
          labels = {
            alias = getAlias m.metaConfig.host;
            fqdn = m.metaConfig.host.fqdn;
            domain = m.metaConfig.host.domain;
            location = ensureLocation m.metaConfig.host.location;
            role = m.metaConfig.node.role;
            os = m.metaConfig.spin;
          };
        }) machines;

        mgmtPingConfigs = map (m:
          let
            makeMgmt = hostname:
              let
                parts = splitString "." hostname;
              in concatStringsSep "." ([ "${elemAt parts 0}-mgmt" ] ++ (tail parts));

            fqdn = makeMgmt m.metaConfig.host.fqdn;
          in {
            targets = [ fqdn ];
            labels = {
              alias = getAlias m.metaConfig.host;
              fqdn = fqdn;
              domain = m.metaConfig.host.domain;
              location = ensureLocation m.metaConfig.host.location;
              role = m.metaConfig.node.role;
              os = m.metaConfig.spin;
            };
          }) machines;
      };

    sshExporters =
      let
        sshExporterServices = flatten (map (m:
          filterServices m (sv: sv.monitor == "ssh-exporter")
        ) monitoredMachines);
      in {
        exporterConfigs = map (sv: {
          targets = [ "${sv.svConfig.address}:${toString sv.svConfig.port}" ];
          labels = {
            service = "ssh-exporter";
          };
        }) sshExporterServices;
      };

    dnsResolvers =
      let
        resolverServices = flatten (map (m:
          filterServices m (sv: sv.monitor == "dns-resolver")
        ) monitoredMachines);

        kresdMetricsServices = flatten (map (m:
          filterServices m (sv: sv.monitor == "kresd-management")
        ) monitoredMachines);
      in {
        dnsProbes = map (sv: {
          targets = [ "${sv.svConfig.address}:${toString sv.svConfig.port}" ];
          labels = {
            fqdn = sv.machine.metaConfig.host.fqdn;
            domain = sv.machine.metaConfig.host.domain;
            location = ensureLocation sv.machine.metaConfig.host.location;
            service = "dns-resolver";
          };
        }) resolverServices;

        kresdConfigs = map (sv: {
          targets = [ "${sv.svConfig.address}:${toString sv.svConfig.port}" ];
          labels = {
            fqdn = sv.machine.metaConfig.host.fqdn;
            domain = sv.machine.metaConfig.host.domain;
            location = ensureLocation sv.machine.metaConfig.host.location;
            service = "dns-resolver";
          };
        }) kresdMetricsServices;
      };

    dnsAuthoritatives =
      let
        authoritativeServices = flatten (map (m:
          filterServices m (sv: sv.monitor == "dns-authoritative")
        ) monitoredMachines);

        bindExporterServices = flatten (map (m:
          filterServices m (sv: sv.monitor == "bind-exporter")
        ) monitoredMachines);
      in {
        dnsProbes = map (sv: {
          targets = [ "${sv.svConfig.address}:${toString sv.svConfig.port}" ];
          labels = {
            fqdn = sv.machine.metaConfig.host.fqdn;
            domain = sv.machine.metaConfig.host.domain;
            location = ensureLocation sv.machine.metaConfig.host.location;
            service = "dns-authoritative";
          };
        }) authoritativeServices;

        bindConfigs = map (sv: {
          targets = [ "${sv.svConfig.address}:${toString sv.svConfig.port}" ];
          labels = {
            fqdn = sv.machine.metaConfig.host.fqdn;
            domain = sv.machine.metaConfig.host.domain;
            location = ensureLocation sv.machine.metaConfig.host.location;
            service = "dns-authoritative";
          };
        }) bindExporterServices;
      };

    rabbitmq =
      let
        rabbitmqServices = flatten (map (m:
          filterServices m (sv: sv.monitor == "rabbitmq")
        ) monitoredMachines);
      in {
        exporterConfigs = map (sv: {
          targets = [ "${sv.svConfig.address}:${toString sv.svConfig.port}" ];
          labels = {
            fqdn = sv.machine.metaConfig.host.fqdn;
            domain = sv.machine.metaConfig.host.domain;
            location = ensureLocation sv.machine.metaConfig.host.location;
            service = "rabbitmq";
          };
        }) rabbitmqServices;
      };

    haproxy =
      let
        haproxyServices = flatten (map (m:
          filterServices m (sv: sv.monitor == "haproxy-exporter")
        ) monitoredMachines);
      in {
        exporterConfigs = map (sv: {
          targets = [ "${sv.svConfig.address}:${toString sv.svConfig.port}" ];
          labels = {
            fqdn = sv.machine.metaConfig.host.fqdn;
            domain = sv.machine.metaConfig.host.domain;
            location = ensureLocation sv.machine.metaConfig.host.location;
            service = "haproxy";
          };
        }) haproxyServices;
      };

    varnish =
      let
        varnishServices = flatten (map (m:
          filterServices m (sv: sv.monitor == "varnish-exporter")
        ) monitoredMachines);
      in {
        exporterConfigs = map (sv: {
          targets = [ "${sv.svConfig.address}:${toString sv.svConfig.port}" ];
          labels = {
            fqdn = sv.machine.metaConfig.host.fqdn;
            domain = sv.machine.metaConfig.host.domain;
            location = ensureLocation sv.machine.metaConfig.host.location;
            service = "varnish";
          };
        }) varnishServices;
      };

    http =
      let
        sites = import ./http.nix;
      in {
        jobs = mapAttrsToList (name: site: {
          job_name = "http_${name}";
          scrape_interval = "300s";
          metrics_path = "/probe";
          params = {
            module = [ "${name}_http_2xx" ];
          };
          static_configs = [
            {
              targets = site.targets;
              labels = site.labels;
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
        }) sites;

        blackboxModules = mapAttrs' (name: site: nameValuePair "${name}_http_2xx" {
          prober = "http";
          timeout = "5s";
          http = {
            valid_http_versions = [ "HTTP/1.1" "HTTP/2.0" ];
            method = "GET";
            headers = {
              Host = site.host;
            };
            preferred_ip_protocol = "ip4";
          };
        }) sites;
      };

    outboundNet = {
      pingConfigs = map (addr: {
        targets = [ addr ];
        labels = {
          alias = "outbound-net";
          address = addr;
        };
      }) [
        "37.9.169.172" # websupport.sk, ~8ms
        "93.188.1.250" # loopia.se, ~30ms
      ];
    };

    jitsiMeet = {
      jvbConfigs = flatten (mapAttrsToList (project: conf:
        mapAttrsToList (name: addr: {
          targets = map (port: "${addr}:${toString port}") conf.jvbExporterPorts;
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

    ipv6Tunnels =
      let
        ips = {
          ipv4 = "37.205.8.113";
          ipv6-interface = "2a03:3b40:fe:33f::1";
          ipv6-tunnel = "2a03:3b40:200::200";
        };
      in {
        pingConfigs = mapAttrsToList (ipv: addr: {
          targets = [ addr ];
          labels = {
            alias = "ipv6tunnels-${ipv}";
            type = "ipv6tunnel";
            address = addr;
          };
        }) ips;
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

      monitorMachines = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = ''
          If set, monitor only the selected machines
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    networking = {
      firewall.extraCommands = concatMapStringsSep "\n" (machine:
        let
          m = confLib.findMetaConfig {
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
            job_name = "log";
            scrape_interval = "60s";
            static_configs = scrapeConfigs.loggers.exporterConfigs;
          }
        ] ++ [
          {
            job_name = "nodes";
            scrape_interval = "30s";
            scrape_timeout = "30s";
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
        ) ++ (optional (scrapeConfigs.nodes.mgmtPingConfigs != [])
          {
            job_name = "nodes-mgmt-ping";
            scrape_interval = "60s";
            metrics_path = "/probe";
            params = {
              module = [ "icmp" ];
            };
            static_configs = scrapeConfigs.nodes.mgmtPingConfigs;
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
            job_name = "nodes-ipmi";
            scrape_interval = "120s";
            scrape_timeout = "60s";
            static_configs = scrapeConfigs.nodes.ipmiConfigs;
          }
        ] ++ [
          {
            job_name = "infra";
            scrape_interval = "60s";
            scrape_timeout = "30s";
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
        ) ++ (optional (scrapeConfigs.sshExporters.exporterConfigs != [])
          {
            job_name = "ssh-exporters";
            scrape_interval = "30s";
            static_configs = scrapeConfigs.sshExporters.exporterConfigs;
          }
        ) ++ (optional (scrapeConfigs.dnsResolvers.kresdConfigs != [])
          {
            job_name = "kresd-management";
            scrape_interval = "60s";
            static_configs = scrapeConfigs.dnsResolvers.kresdConfigs;
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
        ) ++ (optional (scrapeConfigs.dnsAuthoritatives.bindConfigs != [])
          {
            job_name = "bind-exporters";
            scrape_interval = "60s";
            static_configs = scrapeConfigs.dnsAuthoritatives.bindConfigs;
          }
        ) ++ (optional (scrapeConfigs.rabbitmq.exporterConfigs != [])
          {
            job_name = "rabbitmq";
            scrape_interval = "30s";
            static_configs = scrapeConfigs.rabbitmq.exporterConfigs;
          }
        ) ++ (optional (scrapeConfigs.haproxy.exporterConfigs != [])
          {
            job_name = "haproxy";
            scrape_interval = "60s";
            static_configs = scrapeConfigs.haproxy.exporterConfigs;
          }
        ) ++ (optional (scrapeConfigs.varnish.exporterConfigs != [])
          {
            job_name = "varnish";
            scrape_interval = "60s";
            static_configs = scrapeConfigs.varnish.exporterConfigs;
          }
        ) ++ scrapeConfigs.http.jobs ++ [
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
          {
            job_name = "outbound-net-ping";
            scrape_interval = "15s";
            metrics_path = "/probe";
            params = {
              module = [ "icmp" ];
            };
            static_configs = scrapeConfigs.outboundNet.pingConfigs;
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
            job_name = "ipv6-tunnels-ping";
            scrape_interval = "15s";
            metrics_path = "/probe";
            params = {
              module = [ "icmp" ];
            };
            static_configs = scrapeConfigs.ipv6Tunnels.pingConfigs;
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
                    alerter = confLib.findMetaConfig {
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

        ruleConfigs = flatten ((map (v: import v) [
          ./rules/common.nix
          ./rules/nodes.nix
          ./rules/monitoring.nix
          ./rules/infra.nix
          ./rules/dns.nix
          ./rules/smartmon.nix
          ./rules/time-of-day.nix
          ./rules/meet.nix
          ./rules/vpsfree-web.nix
          ./rules/systemd.nix
          ./rules/nodectld.nix
          ./rules/syslog.nix
          ./rules/ipmi.nix
          ./rules/outbound-net.nix
          ./rules/ipv6-tunnels.nix
        ]) ++ (map (v: import v { inherit lib; }) [
          ./rules/test.nix
          ./rules/vpsadmin.nix
        ]));
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
            modules = staticModules // scrapeConfigs.http.blackboxModules // meetModules;
          });
        };
    };

    systemd.services."prometheus-blackbox-exporter".serviceConfig = {
      CapabilityBoundingSet = [ "CAP_NET_RAW" ];
    };
  };
}
