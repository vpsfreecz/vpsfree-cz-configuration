{ config, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 11514 ]; # tcp rsyslog
  networking.firewall.allowedUDPPorts = [ 12201 11515 ]; # gelf, upd rsyslog

  services.graylog = {
    enable = true;
    # pwgen -N 1 -s 96
    passwordSecret = lib.fileContents ../static/graylog/passwordSecretSalt;
    # echo -n somepass | shasum -a 256
    rootPasswordSha2 = "670ddd27b448503bdb66dab9d3f978f7da2b6eb38f36e4268647c76203ab807f";
    elasticsearchHosts = [ "http://localhost:9200" ];
    extraConfig = ''
      web_endpoint_uri = http://graylog.vpsfree.cz/api/
      rest_listen_uri = http://127.0.0.1:9000/api/
      web_listen_uri = http://127.0.0.1:9000/
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
            proxyPass = "http://localhost:9000";
          };
        };
      };
    };
  };
}

