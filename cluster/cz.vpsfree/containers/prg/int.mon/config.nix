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

  allDeployments = confLib.getClusterDeployments config.cluster;

  monitoredDeployments = filter (d: d.config.monitoring.enable) allDeployments;

  getAlias = host: "${host.name}${optionalString (!isNull host.location) ".${host.location}"}";
  ensureLocation = location: if location == null then "global" else location;

  filterServices = d: fn:
    let
      serviceList = mapAttrsToList (name: config: {
        deployment = d;
        inherit name config;
      }) d.config.services;
    in
      filter (sv: fn sv.config) serviceList;

  scrapeConfigs = {
    monitorings =
      let
        deps = filter (d:
          d.config.monitoring.isMonitor && d.config.host.fqdn != confMachine.host.fqdn
        ) monitoredDeployments;
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
        ] ++ (flatten (map (d: {
          targets = [
            "${d.config.host.fqdn}:${toString d.services.prometheus.port}"
            "${d.config.host.fqdn}:${toString d.services.node-exporter.port}"
          ];
          labels = {
            alias = getAlias d.config.host;
            fqdn = d.config.host.fqdn;
          } // d.config.monitoring.labels;
        }) deps));

        pingConfigs = map (d: {
          targets = [ d.config.host.fqdn ];
          labels = {
            alias = getAlias d.config.host;
            fqdn = d.config.host.fqdn;
            domain = d.config.host.domain;
            location = realLocation d.config.host.location;
            os = d.config.spin;
          };
        }) deps;
      };

    infra =
      let
        deps = filter (d:
          !d.config.monitoring.isMonitor && (d.config.node == null)
        ) monitoredDeployments;

        exporterDeps = filter (d: d.config.spin != "other") deps;
      in {
        exporterConfigs = map (d: {
          targets = [
            "${d.config.host.fqdn}:${toString d.config.services.node-exporter.port}"
          ] ++ (optional (hasAttr "osctl-exporter" d.config.services) "${d.config.host.fqdn}:${toString d.config.services.osctl-exporter.port}");
          labels = {
            alias = getAlias d.config.host;
            fqdn = d.config.host.fqdn;
            domain = d.config.host.domain;
            location = ensureLocation d.config.host.location;
            os = d.config.spin;
          } // d.config.monitoring.labels;
        }) exporterDeps;

        pingConfigs = map (d: {
          targets = [ d.config.host.fqdn ];
          labels = {
            alias = getAlias d.config.host;
            fqdn = d.config.host.fqdn;
            domain = d.config.host.domain;
            location = ensureLocation d.config.host.location;
            os = d.config.spin;
          };
        }) deps;
      };

    nodes =
      let
        deps = filter (d: d.config.node != null) monitoredDeployments;
      in {
        exporterConfigs = map (d: {
          targets = [
            "${d.config.host.fqdn}:${toString d.config.services.node-exporter.port}"
          ] ++ (optional (hasAttr "osctl-exporter" d.config.services) "${d.config.host.fqdn}:${toString d.config.services.osctl-exporter.port}");
          labels = {
            alias = getAlias d.config.host;
            fqdn = d.config.host.fqdn;
            domain = d.config.host.domain;
            location = ensureLocation d.config.host.location;
            type = "node";
            os = d.config.spin;
            role = d.config.node.role;
          } // d.config.monitoring.labels;
        }) deps;

        pingConfigs = map (d: {
          targets = [ d.config.host.fqdn ];
          labels = {
            alias = getAlias d.config.host;
            fqdn = d.config.host.fqdn;
            domain = d.config.host.domain;
            location = ensureLocation d.config.host.location;
            role = d.config.node.role;
            os = d.config.spin;
          };
        }) deps;
      };

    dnsResolvers =
      let
        resolverServices = flatten (map (d:
          filterServices d (sv: sv.monitor == "dns-resolver")
        ) monitoredDeployments);
      in {
        dnsProbes = map (sv: {
          targets = [ "${sv.config.address}:${toString sv.config.port}" ];
          labels = {
            fqdn = sv.deployment.config.host.fqdn;
            domain = sv.deployment.config.host.domain;
            location = ensureLocation sv.deployment.config.host.location;
            service = "dns-resolver";
          };
        }) resolverServices;
      };

    dnsAuthoritatives =
      let
        authoritativeServices = flatten (map (d:
          filterServices d (sv: sv.monitor == "dns-authoritative")
        ) monitoredDeployments);
      in {
        dnsProbes = map (sv: {
          targets = [ "${sv.config.address}:${toString sv.config.port}" ];
          labels = {
            fqdn = sv.deployment.config.host.fqdn;
            domain = sv.deployment.config.host.domain;
            location = ensureLocation sv.deployment.config.host.location;
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
