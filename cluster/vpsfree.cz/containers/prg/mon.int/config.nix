{ pkgs, lib, confLib, config, deploymentInfo, ... }:
with lib;
let
  alertsPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "vpsfree.cz";
    location = "prg";
    name = "alerts.int";
  };

  grafanaPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "vpsfree.cz";
    location = "prg";
    name = "grafana.int";
  };

  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    domain = "vpsfree.cz";
    location = "prg";
    name = "proxy";
  };

  promPort = deploymentInfo.config.services.prometheus.port;
  exporterPort = deploymentInfo.config.services.node-exporter.port;

  allDeployments = confLib.getClusterDeployments config.cluster;

  getAlias = d: "${d.name}${optionalString (!isNull d.location) ".${d.location}"}";
  ensureLocation = location: if location == null then "global" else location;

  scrapeConfigs = {
    monitorings =
      let
        deps = filter (d:
          d.config.monitoring.enable && d.config.monitoring.isMonitor && d.fqdn != deploymentInfo.fqdn
        ) allDeployments;
      in {
        exporterConfigs = [
          {
            targets = [
              "localhost:${toString promPort}"
              "localhost:${toString exporterPort}"
            ];
            labels = {
              alias = getAlias deploymentInfo;
              fqdn = deploymentInfo.fqdn;
            } // deploymentInfo.config.monitoring.labels;
          }
        ] ++ (flatten (map (d: {
          targets = [
            "${d.fqdn}:${toString d.services.prometheus.port}"
            "${d.fqdn}:${toString d.services.node-exporter.port}"
          ];
          labels = {
            alias = getAlias d;
            fqdn = d.fqdn;
          } // d.config.monitoring.labels;
        }) deps));

        pingConfigs = map (d: {
          targets = [ d.fqdn ];
          labels = {
            domain = d.domain;
            location = realLocation d.location;
            os = d.spin;
          };
        }) deps;
      };

    infra =
      let
        deps = filter (d:
          d.config.monitoring.enable && !d.config.monitoring.isMonitor && (d.type == "machine" || d.type == "container")
        ) allDeployments;
      in {
        exporterConfigs = map (d: {
          targets = [
            "${d.fqdn}:${toString d.config.services.node-exporter.port}"
          ] ++ (optional (hasAttr "osctl-exporter" d.config.services) "${d.fqdn}:${toString d.config.services.osctl-exporter.port}");
          labels = {
            alias = getAlias d;
            fqdn = d.fqdn;
            domain = d.domain;
            location = ensureLocation d.location;
            type = d.type;
            os = d.spin;
          } // d.config.monitoring.labels;
        }) deps;

        pingConfigs = map (d: {
          targets = [ d.fqdn ];
          labels = {
            domain = d.domain;
            location = ensureLocation d.location;
            os = d.spin;
          };
        }) deps;
      };

    nodes =
      let
        deps = filter (d:
          d.config.monitoring.enable && d.type == "node"
        ) allDeployments;
      in {
        exporterConfigs = map (d: {
          targets = [
            "${d.fqdn}:${toString d.config.services.node-exporter.port}"
          ] ++ (optional (hasAttr "osctl-exporter" d.config.services) "${d.fqdn}:${toString d.config.services.osctl-exporter.port}");
          labels = {
            alias = getAlias d;
            fqdn = d.fqdn;
            domain = d.domain;
            location = ensureLocation d.location;
            type = d.type;
            os = d.spin;
            role = d.role;
          } // d.config.monitoring.labels;
        }) deps;

        pingConfigs = map (d: {
          targets = [ d.fqdn ];
          labels = {
            domain = d.domain;
            location = ensureLocation d.location;
            role = d.role;
            os = d.spin;
          };
        }) deps;
      };
  };
in {
  imports = [
    ../../../../../environments/base.nix
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
      listenAddress = "0.0.0.0:${toString promPort}";
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
      );

      alertmanagerURL = [
        "${alertsPrg.services.alertmanager.address}:${toString alertsPrg.services.alertmanager.port}"
      ];

      ruleConfigs = flatten (map (v: import v) [
        ./rules/common.nix
        ./rules/nodes.nix
        ./rules/infra.nix
        ./rules/time-of-day.nix
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
      '';
    };
  };
}
