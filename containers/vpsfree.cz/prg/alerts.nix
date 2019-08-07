{ pkgs, lib, config, ... }:
{
  imports = [
    ../../../env.nix
    ../../../profiles/ct.nix
    ../../../modules/monitored.nix
  ];

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
        "receiver" = "team-admins";
      };
      "receivers" = [
        {
          "name" = "team-admins";
          "email_configs" = [
            {
              "to" = "aither@havefun.cz";
              "send_resolved" = true;
            }
          ];
        }
      ];
    };
  };

  services.postfix.enable = true;
}
