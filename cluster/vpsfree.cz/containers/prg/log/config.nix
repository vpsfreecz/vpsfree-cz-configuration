{ config, pkgs, lib, confLib, deploymentInfo, ... }:
with lib;
let
  rsyslogTcpPort = deploymentInfo.config.services.graylog-rsyslog-tcp.port;
  rsyslogUdpPort = deploymentInfo.config.services.graylog-rsyslog-udp.port;
  gelfPort = deploymentInfo.config.services.graylog-gelf.port;

  loggedAddresses = filter (a:
    a.config.logging.enable
  ) (confLib.getAllAddressesOf config.cluster 4);
in {
  imports = [
    ../../../../../environments/base.nix
  ];

  networking.firewall = {
    allowedTCPPorts = [ 80 ];
    extraCommands = ''
      ${concatMapStringsSep "\n" (a: ''
        # Allow access from ${a.fqdn} @ ${a.address}
        iptables -A nixos-fw -p tcp -s ${a.address} --dport ${toString rsyslogTcpPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp -s ${a.address} --dport ${toString rsyslogUdpPort} -j nixos-fw-accept
        iptables -A nixos-fw -p udp -s ${a.address} --dport ${toString gelfPort} -j nixos-fw-accept
      '') loggedAddresses}
    '';
  };

  services.graylog = {
    enable = true;
    # pwgen -N 1 -s 96
    passwordSecret = lib.fileContents /secrets/graylog/passwordSecretSalt;
    # echo -n somepass | shasum -a 256
    rootPasswordSha2 = "86a09e9fb695d0a2d17439318566b69d4f04486cf96a422473d9b7ee782d4845";
    elasticsearchHosts = [ "http://localhost:9200" ];
    extraConfig = ''
      http_bind_address = 127.0.0.1:9000
      http_publish_uri  = http://log.prg.vpsfree.cz/
      http_external_uri = http://log.prg.vpsfree.cz/
      '';
  };

  services.elasticsearch = {
    enable = true;
    package = pkgs.elasticsearch5;
  };

  services.mongodb = {
    enable = true;
  };

  services.SystemdJournal2Gelf = {
    enable = true;
    graylogServer = "127.0.0.1:${toString gelfPort}";
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts = {
      "log.prg.vpsfree.cz" = {
        default = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:9000";
          };
        };
      };
    };
  };

  deployment = {
    healthChecks = {
      http = [
        {
          scheme = "http";
          port = 80;
          path = "/";
          description = "Check whether nginx is running.";
        }
      ];
    };
  };
}

