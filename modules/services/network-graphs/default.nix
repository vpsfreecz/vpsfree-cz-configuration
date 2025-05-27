{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.services.network-graphs;

  fetchGraphs = pkgs.replaceVarsWith {
    src = ./fetch-graphs.rb;
    isExecutable = true;
    replacements = {
      ruby = pkgs.ruby;
    };
  };

  dir = "/run/network-graphs";

  user = config.services.nginx.user;

  group = config.services.nginx.group;
in {
  options = {
    services.network-graphs = {
      enable = mkEnableOption ''
        Enable network graphs fetch service

        The service includes a timer which periodically fetches hardcoded graphs
        and saves them as local files to be served by nginx.
      '';

      path = mkOption {
        type = types.str;
        default = "network-graphs";
        description = ''
          Path at which the graphs are stored

          This determines also the path within nginx at which the files
          are served.
        '';
      };

      virtualHost = mkOption {
        type = types.str;
        description = ''
          Name of an nginx virtual host to which the graph directory
          is inserted
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${dir}' 0755 ${user} ${group} - -"
    ];

    systemd.services.network-graphs = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        curl
      ];
      serviceConfig = {
        Type = "simple";
        User = user;
        Group = group;
        ExecStart = "${fetchGraphs} ${dir}/${cfg.path}";
      };
    };

    systemd.timers.network-graphs = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5s";
        OnUnitActiveSec = "5min";
      };
    };

    services.nginx.virtualHosts.${cfg.virtualHost} = {
      locations."/${cfg.path}".root = dir;
    };
  };
}
