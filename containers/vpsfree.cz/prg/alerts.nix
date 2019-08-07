{ pkgs, lib, config, ... }:
{
  imports = [
    ../../../env.nix
    ../../../profiles/ct.nix
    ../../../modules/monitored.nix
    ../../../modules/services/sachet.nix
  ];

  nixpkgs.overlays = import ../../../overlays;

  networking = {
    firewall.allowedTCPPorts = [
      9093  # alertmanager
    ];
  };

  services.prometheus.alertmanager = {
    enable = true;
    configuration = {
      "global" = {
        "smtp_smarthost" = "localhost:25";
        "smtp_from" = "alertmanager@vpsfree.cz";
        "smtp_require_tls" = false;
      };
      "route" = {
        "group_by" = [ "alertname" "alias" ];
        "group_wait" = "30s";
        "group_interval" = "2m";
        "repeat_interval" = "4h";
        "receiver" = "team-mail";

        "routes" = [
          {
            "match" = {
              "severity" = "critical";
            };
            "receiver" = "team-sms";
            "group_wait" = "10s";
            "repeat_interval" = "10m";
          }
        ];
      };
      "receivers" = [
        {
          "name" = "team-mail";
          "email_configs" = [
            {
              "to" = "aither@havefun.cz,snajpa@snajpa.net";
              "send_resolved" = true;
            }
          ];
        }
        {
          "name" = "team-sms";
          "webhook_configs" = [
            {
              "url" = "http://localhost:9876/alert";
              "send_resolved" = true;
            }
          ];
        }
      ];
    };
  };

  services.postfix.enable = true;

  services.sachet = {
    enable = true;
    configPath = "/private/sachet/config.yml";
  };
}
