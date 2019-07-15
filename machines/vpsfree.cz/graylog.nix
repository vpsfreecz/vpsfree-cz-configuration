{ config, pkgs, lib, ... }:

{

  imports = [
    ../../modules/monitored.nix
  ];

  networking.firewall.allowedTCPPorts = [ 80 11514 ];    # web,  tcp rsyslog
  networking.firewall.allowedUDPPorts = [ 12201 11515 ]; # gelf, upd rsyslog

  services.graylog = {
    enable = true;
    # pwgen -N 1 -s 96
    passwordSecret = lib.fileContents /secrets/graylog/passwordSecretSalt;
    # echo -n somepass | shasum -a 256
    rootPasswordSha2 = "670ddd27b448503bdb66dab9d3f978f7da2b6eb38f36e4268647c76203ab807f";
    elasticsearchHosts = [ "http://localhost:9200" ];
    extraConfig = ''
      http_bind_address = 127.0.0.1:9000
      http_publish_uri  = http://log.vpsfree.cz/
      http_external_uri = http://log.vpsfree.cz/
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
    graylogServer = "127.0.0.1:12201";
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts = {
      "graylog" = {
        default = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:9000";
          };
        };
      };
    };
  };
}

