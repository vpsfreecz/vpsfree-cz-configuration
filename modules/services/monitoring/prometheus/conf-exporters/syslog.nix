{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.prometheus.confExporters.syslog;

  defaultUser = "syslog-exporter";

  settingsFormat = pkgs.formats.json { };

  configurationJson = settingsFormat.generate "syslog-exporter.json" cfg.settings;

  rackupConfig = pkgs.writeText "syslog-exporter.ru" ''
    require 'syslog-exporter/rackup'

    run SyslogExporter::Rackup.app('${configurationJson}')
  '';

  pumaConfig = pkgs.writeText "syslog-exporter.rb" ''
    bind 'tcp://${cfg.listenAddress}:${toString cfg.port}'
    rackup '${rackupConfig}'
    environment 'production'
    tag 'syslog-exporter'
  '';
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
      environment.RACK_ENV = "production";
      serviceConfig = {
        Type = "notify";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        ExecStart = "${cfg.package}/bin/puma -C ${pumaConfig}";
        Restart = "on-failure";
        RestartSec = 30;
        WatchdogSec = 10;
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
