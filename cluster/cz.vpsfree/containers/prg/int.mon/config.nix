{ pkgs, lib, confLib, config, confMachine, ... }:
with lib;
let
  alertsPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.alerts";
  };

  grafanaPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.grafana";
  };

  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

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

    jitsiMeet =
      let
        videoBridges = {
          vpsfree = {
            "jvb1" = "37.205.14.168";
            "jvb2" = "37.205.14.153";
            "jvb3" = "37.205.12.167";
            "jvb4" = "37.205.12.173";
            "jvb5" = "37.205.12.178";
            "jvb6" = "37.205.12.180";
            "jvb7" = "37.205.14.129";
            "jvb8" = "37.205.14.154";
            "jvb9" = "37.205.14.3";
            "jvb10" = "83.167.228.190";
            "jvb11" = "83.167.228.189";
            "jvb12" = "37.205.14.235";
            "jvb13" = "83.167.228.187";
            "jvb14" = "83.167.228.179";
            "jvb15" = "83.167.228.178";
            "jvb16" = "185.8.164.60";
          };

          linuxdays = {
            "ld-jvb1" = "37.205.8.129";
            "ld-jvb2" = "37.205.8.211";
            "ld-jvb3" = "37.205.8.244";
            "ld-jvb4" = "37.205.12.30";
            "ld-jvb5" = "37.205.12.33";
            "ld-jvb6" = "37.205.12.55";
          };
        };
      in {
        jvbConfigs = flatten (mapAttrsToList (project: bridges:
          mapAttrsToList (name: addr: {
            targets = [ "${addr}:9100" ];
            labels = {
              alias = "meet-${name}";
              type = "meet-jvb";
              project = project;
            };
          }) bridges) videoBridges);

        jvbPingConfigs = flatten (mapAttrsToList (project: bridges:
          mapAttrsToList (name: addr: {
            targets = [ addr ];
            labels = {
              alias = "meet-${name}";
              type = "meet-jvb";
              project = project;
            };
          }) bridges) videoBridges);

        webConfigs = [
          {
            targets = [ "https://meet.vpsfree.cz" ];
            labels = {
              alias = "meet.vpsfree.cz";
              type = "meet-web";
            };
          }
          {
            targets = [ "https://meet.linuxdays.cz" ];
            labels = {
              alias = "meet.linuxdays.cz";
              type = "meet-web";
            };
          }
        ];
      };
  };
in {
  imports = [
    ../../../../../environments/base.nix
    ../../../../../profiles/ct.nix
  ];

  networking = {
    firewall.extraCommands = ''
      # Allow access to prometheus from proxy.prg
      iptables -A nixos-fw -p tcp --dport ${toString promPort} -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept

      # Allow access to prometheus from grafana.int.prg
      iptables -A nixos-fw -p tcp --dport ${toString promPort} -s ${grafanaPrg.addresses.primary.address} -j nixos-fw-accept
    '';
  };

  services = {
    prometheus = {
      enable = true;
      extraFlags = [
        "--storage.tsdb.retention.time 365d"
        "--storage.tsdb.retention.size 200GB"
      ];
      listenAddress = "0.0.0.0";
      port = promPort;
      webExternalUrl = "https://mon.prg.vpsfree.cz/";
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
          job_name = "meet-web";
          scrape_interval = "60s";
          metrics_path = "/probe";
          params = {
            module = [ "meet_http_2xx" ];
          };
          static_configs = scrapeConfigs.jitsiMeet.webConfigs;
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
      ];

      alertmanagers = [
        {
          scheme = "http";
          static_configs = [
            {
              targets = [
                "${alertsPrg.services.alertmanager.address}:${toString alertsPrg.services.alertmanager.port}"
              ];
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
      ]);
    };

    prometheus.exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      configFile = pkgs.writeText "blackbox.yml" ''
        modules:
          icmp:
            prober: icmp
            timeout: 5s
            icmp:
              preferred_ip_protocol: "ip4"
          dns_resolver:
            prober: dns
            dns:
              query_name: google.com
              query_type: A
              transport_protocol: tcp
          dns_authoritative:
            prober: dns
            dns:
              query_name: vpsfree.cz
              query_type: A
              transport_protocol: tcp
          meet_http_2xx:
            prober: http
            timeout: 5s
            http:
              valid_http_versions: ["HTTP/1.1", "HTTP/2"]
              method: GET
              headers:
                Host: meet.vpsfree.cz
              preferred_ip_protocol: ip4
      '';
    };
  };
}
