{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.ssh-exporter;

  defaultUser = "ssh-exporter";

  settingsFormat = pkgs.formats.json { };

  configurationJson = settingsFormat.generate "ssh-exporter.json" cfg.settings;

  rackupConfig = pkgs.writeText "ssh-exporter.ru" ''
    require 'ssh-exporter/rackup'

    run SshExporter::Rackup.app('${configurationJson}')
  '';

  thinYml = pkgs.writeText "thin.yml" ''
    address: ${cfg.address}
    port: ${toString cfg.port}
    rackup: ${rackupConfig}
    environment: production
    tag: ssh-exporter
  '';
in {
  options = {
    services.ssh-exporter = {
      enable = mkEnableOption "Enable ssh-exporter";

      package = mkOption {
        type = types.package;
        default = pkgs.ssh-exporter;
        description = "Which ssh-exporter package to use.";
      };

      user = mkOption {
        type = types.str;
        default = defaultUser;
        description = "User under which ssh-exporter is run.";
      };

      group = mkOption {
        type = types.str;
        default = defaultUser;
        description = "Group under which ssh-exporter is run.";
      };

      address = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Address on which ssh-exporter is run.";
      };

      port = mkOption {
        type = types.int;
        default = 9103;
        description = "Port on which ssh-exporter is run.";
      };

      stateDir = mkOption {
        type = types.str;
        default = "/var/ssh-exporter";
        description = "The state directory";
      };

      settings = mkOption {
        type = types.submodule {
          freeformType = settingsFormat.type;
        };
        default = {};
        description = ''
          ssh-exporter configuration options
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.ssh-exporter = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        openssh
      ];
      environment.RACK_ENV = "production";
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        ExecStart = "${cfg.package}/bin/thin --config ${thinYml} start";
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
      ${cfg.group} = {};
    };
  };
}
