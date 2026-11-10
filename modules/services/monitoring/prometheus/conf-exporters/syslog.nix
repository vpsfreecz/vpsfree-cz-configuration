{
  config,
  pkgs,
  lib,
  utils,
  ...
}:
with lib;
let
  cfg = config.services.prometheus.confExporters.syslog;

  defaultUser = "syslog-exporter";

  settingsFormat = pkgs.formats.json { };

  configurationJson = settingsFormat.generate "syslog-exporter.json" cfg.settings;

  listenAddress =
    if hasInfix ":" cfg.listenAddress && !hasPrefix "[" cfg.listenAddress then
      "[${cfg.listenAddress}]"
    else
      cfg.listenAddress;
in
{
  options = {
    services.prometheus.confExporters.syslog = {
      enable = mkEnableOption "Enable syslog-exporter";

      package = mkOption {
        type = types.package;
        default = pkgs.syslog-exporter;
        description = "Which syslog-exporter package to use.";
      };

      user = mkOption {
        type = types.str;
        default = defaultUser;
        description = "User under which syslog-exporter is run.";
      };

      group = mkOption {
        type = types.str;
        default = defaultUser;
        description = "Group under which syslog-exporter is run.";
      };

      listenAddress = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Address on which syslog-exporter is run.";
      };

      port = mkOption {
        type = types.int;
        default = 9102;
        description = "Port on which syslog-exporter is run.";
      };

      stateDir = mkOption {
        type = types.str;
        default = "/var/syslog-exporter";
        description = "The state directory";
      };

      settings = mkOption {
        type = types.submodule {
          freeformType = settingsFormat.type;
        };
        default = { };
        description = ''
          syslog-exporter configuration options
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.prometheus.confExporters.syslog.settings.syslog_pipe = mkDefault "/var/log/rsyslog.pipe";

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0750 ${cfg.user} ${cfg.group} - -"
      "p '${cfg.settings.syslog_pipe}' 0640 root ${cfg.group} - -"
    ];

    systemd.services.prometheus-syslog-exporter = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        ExecStart = utils.escapeSystemdExecArgs [
          "${cfg.package}/bin/syslog-exporter"
          "--config"
          configurationJson
          "--listen"
          "${listenAddress}:${toString cfg.port}"
        ];
        Restart = "on-failure";
        RestartSec = 30;
      };
    };

    users.users = optionalAttrs (cfg.user == defaultUser) {
      ${cfg.user} = {
        group = cfg.group;
        home = cfg.stateDir;
        isSystemUser = true;
      };
    };

    users.groups = optionalAttrs (cfg.group == defaultUser) {
      ${cfg.group} = { };
    };
  };
}
