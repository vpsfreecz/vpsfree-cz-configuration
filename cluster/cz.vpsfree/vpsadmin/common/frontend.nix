{ pkgs, lib, config, confLib, ... }:
with lib;
let
  db = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.db";
  };

  api1 = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.api1";
  };

  api2 = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.api2";
  };

  webui1 = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.webui1";
  };

  webui2 = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.webui2";
  };

  webuiDev = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.webui-dev";
  };

  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  apis = [ api1 api2 ];

  webuis = [ webui1 webui2 ];
in {
  networking.firewall.extraCommands = concatMapStringsSep "\n" (m: ''
    iptables -A nixos-fw -p tcp -m tcp -s ${m.addresses.primary.address} --dport 5000 -j nixos-fw-accept
  '') (webuis ++ [ webuiDev ]);

  vpsadmin.download-mounter = {
    enable = true;
    api = {
      url = "https://api.vpsfree.cz";
      tokenFile = "/private/vpsadmin-api.token";
    };
    mountpoint = "/mnt/vpsadmin-download";
  };

  vpsadmin.console-router = {
    enable = true;
    database = {
      host = db.addresses.primary.address;
      user = "vpsadmin-console";
      name = "vpsadmin";
      passwordFile = "/private/vpsadmin-db.pw";
    };
  };

  vpsadmin.haproxy = {
    enable = true;

    api.prod = {
      frontend.bind = [
        "unix@/run/haproxy/vpsadmin-api.sock mode 0666"
        "*:5000"
      ];
      backends = flatten (map (m: builtins.genList (i: {
        host = m.addresses.primary.address;
        port = 9292 + i;
      }) 8) apis);
    };

    console-router.prod = {
      frontend.bind = [ "unix@/run/haproxy/vpsadmin-console-router.sock mode 0666" ];
      backends = [
        {
          host = "127.0.0.1";
          port = config.vpsadmin.console-router.port;
        }
      ];
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
        backend = {
          address = "unix:/run/haproxy/vpsadmin-api.sock";
        };
      };

      maintenance = {
        domain = "api-admin.vpsfree.cz";
        backend = {
          address = "unix:/run/haproxy/vpsadmin-api.sock";
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
}
