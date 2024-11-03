{ pkgs, lib, config, confMachine, confLib, ... }:
with lib;
let
  db = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.db";
  };

  api1 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.api1";
  };

  api2 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.api2";
  };

  webui1 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.webui1";
  };

  webui2 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.webui2";
  };

  webuiDev = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.webui-dev";
  };

  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  apis = [ api1 api2 ];

  webuis = [ webui1 webui2 ];

  consoles = apis;

  allMachines = confLib.getClusterMachines config.cluster;

  monitors = filter (m: m.metaConfig.monitoring.isMonitor) allMachines;

  haproxyExporterPort = confMachine.services.haproxy-exporter.port;

  varnishExporterPort = confMachine.services.varnish-exporter.port;
in {
  networking.firewall.extraCommands =
    (concatMapStringsSep "\n" (m: ''
      iptables -A nixos-fw -p tcp -m tcp -s ${m.addresses.primary.address} --dport 5000 -j nixos-fw-accept
    '') (webuis ++ [ webuiDev ]))
    + (concatMapStringsSep "\n" (m: ''
      # haproxy prometheus metrics ${m.name}
      iptables -A nixos-fw -p tcp --dport ${toString haproxyExporterPort} -s ${m.metaConfig.addresses.primary.address} -j nixos-fw-accept

      # varnish exporter ${m.name}
      iptables -A nixos-fw -p tcp --dport ${toString varnishExporterPort} -s ${m.metaConfig.addresses.primary.address} -j nixos-fw-accept
    '') monitors);

  systemd.tmpfiles.rules = [
    "d /run/varnish 0755 varnish varnish -"
  ];

  vpsadmin.download-mounter = {
    enable = true;
    api = {
      url = "https://api.vpsfree.cz";
      tokenFile = "/private/vpsadmin-api.token";
    };
    mountpoint = "/mnt/vpsadmin-download";
  };

  vpsadmin.haproxy = {
    enable = true;

    exporter.port = haproxyExporterPort;

    api.prod = {
      frontend.bind = [
        "unix@/run/haproxy/vpsadmin-api.sock mode 0666"
        "*:5000"
      ];
      backends = map (m: {
        host = m.addresses.primary.address;
        port = 9292;
      }) apis;
    };

    console-router.prod = {
      frontend.bind = [ "unix@/run/haproxy/vpsadmin-console-router.sock mode 0666" ];
      backends = map (m: {
        host = m.addresses.primary.address;
        port = 8000;
      }) consoles;
    };

    webui = {
      prod = {
        frontend.bind = [ "unix@/run/haproxy/vpsadmin-webui-prod.sock mode 0666" ];
        backends = map (m: {
          host = m.addresses.primary.address;
          port = 80;
        }) webuis;
      };

      dev = {
        frontend.bind = [ "unix@/run/haproxy/vpsadmin-webui-dev.sock mode 0666" ];
        backends = [
          {
            host = webuiDev.addresses.primary.address;
            port = 80;
          }
        ];
      };
    };
  };

  vpsadmin.varnish = {
    enable = true;

    bind = "/run/varnish/vpsadmin-varnish.sock,mode=0666";

    api.prod = {
      domain = "api.vpsfree.cz";
      backend.path = "/run/haproxy/vpsadmin-api.sock";
    };

    api.maintenance = {
      domain = "api-admin.vpsfree.cz";
      backend.path = "/run/haproxy/vpsadmin-api.sock";
    };
  };

  vpsadmin.frontend = {
    enable = true;

    maintenance = {
      # enable = true;
      frontends = [ "production" ];
    };

    forceSSL = true;
    enableACME = true;

    api = {
      production = {
        domain = "api.vpsfree.cz";
        aliases = [
          "ipv4.ddns.vpsfree.cz"
          "ipv6.ddns.vpsfree.cz"
        ];
        backend = {
          address = "unix:/run/varnish/vpsadmin-varnish.sock";
        };
      };

      maintenance = {
        domain = "api-admin.vpsfree.cz";
        backend = {
          address = "unix:/run/varnish/vpsadmin-varnish.sock";
        };
      };
    };

    auth = {
      production = {
        domain = "auth.vpsfree.cz";
        backend = {
          address = "unix:/run/varnish/vpsadmin-varnish.sock";
        };
      };

      maintenance = {
        domain = "auth-admin.vpsfree.cz";
        backend = {
          address = "unix:/run/varnish/vpsadmin-varnish.sock";
        };
      };
    };

    console-router = {
      production = {
        domain = "console.vpsfree.cz";
        backend = {
          address = "unix:/run/haproxy/vpsadmin-console-router.sock";
        };
      };

      maintenance = {
        domain = "console-admin.vpsfree.cz";
        backend = {
          address = "unix:/run/haproxy/vpsadmin-console-router.sock";
        };
      };
    };

    download-mounter = {
      production = {
        domain = "download.vpsfree.cz";
      };

      maintenance = {
        domain = "download-admin.vpsfree.cz";
      };
    };

    webui = {
      production = {
        domain = "vpsadmin.vpsfree.cz";
        backend = {
          address = "unix:/run/haproxy/vpsadmin-webui-prod.sock";
        };
      };

      maintenance = {
        domain = "vpsadmin-admin.vpsfree.cz";
        backend = {
          address = "unix:/run/haproxy/vpsadmin-webui-prod.sock";
        };
      };

      dev = {
        domain = "vpsadmin-dev.vpsfree.cz";
        backend = {
          address = "unix:/run/haproxy/vpsadmin-webui-dev.sock";
        };
      };
    };
  };

  services.nginx.virtualHosts.${config.vpsadmin.frontend.webui.dev.virtualHost} = {
    basicAuthFile = "/private/nginx/mon.htpasswd";
  };

  services.network-graphs = {
    enable = true;
    path = "network-graphs";
    virtualHost = "vpsadmin.vpsfree.cz";
  };

  services.prometheus.exporters.varnish = {
    enable = true;
    port = varnishExporterPort;
  };

  users.groups.varnish.members = [ config.services.prometheus.exporters.varnish.user ];
}
