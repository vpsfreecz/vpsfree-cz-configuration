{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.sachet;

  defaultUser = "sachet";

  defaultGroup = defaultUser;

  configFile =
    if cfg.configPath != null then
      cfg.configPath
    else
      pkgs.writeText "sachet-config.json" (builtins.toJSON cfg.settings);
in
{
  options = {
    services.sachet = {
      enable = mkEnableOption "Enable sachet, SMS alerts for Prometheus' Alertmanager";

      listenAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = ''
          Address to listen on.
        '';
      };

      port = mkOption {
        type = types.int;
        default = 9876;
        description = ''
          Port to listen on.
        '';
      };

      user = mkOption {
        type = types.str;
        default = defaultUser;
        description = ''
          User to run as.
        '';
      };

      group = mkOption {
        type = types.str;
        default = defaultGroup;
        description = ''
          Group to run as.
        '';
      };

      configPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Path to the config file passed to sachet.

          The config file contains access tokens to providers, so do not store
          in in the Nix store.
        '';
      };

      settings = mkOption {
        type = types.attrs;
        default = { };
        description = ''
          Create the config file from an attrset.

          Note that these settings are publicly stored in the Nix store, so
          it is not suitable for access tokens, passwords, etc.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (isNull cfg.configPath) || cfg.settings == { };
        message = "Use either services.sachet.configPath or services.sachet.settings";
      }
    ];

    systemd.services.sachet = {
      description = "SMS alerts for Prometheus' Alertmanager";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = toString [
          "${pkgs.sachet}/bin/sachet"
          "-config ${configFile}"
          "-listen-address ${cfg.listenAddress}:${toString cfg.port}"
        ];
        Restart = "on-failure";
      };
    };

    users.users = mkIf (cfg.user == defaultUser) {
      "${cfg.user}" = {
        isSystemUser = true;
        group = cfg.group;
      };
    };

    users.groups = mkIf (cfg.group == defaultGroup) {
      "${cfg.group}".members = [ cfg.user ];
    };
  };
}
