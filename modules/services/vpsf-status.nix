{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.vpsf-status;

  defaultUser = "vpsfstatus";

  defaultGroup = defaultUser;

  settings = {
    listen_address = "${cfg.listenAddress}:${toString cfg.port}";
    data_dir = "${pkgs.vpsf-status}/share/vpsf-status";
  } // cfg.settings;

  configFile = pkgs.writeText "vpsf-status-config.json" (builtins.toJSON settings);
in
{
  options = {
    services.vpsf-status = {
      enable = mkEnableOption "Enable vpsf-status";

      listenAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = ''
          Address to listen on.
        '';
      };

      port = mkOption {
        type = types.int;
        default = 8080;
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

      settings = mkOption {
        type = types.attrs;
        default = { };
        description = ''
          vpsf-status settings
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.vpsf-status = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = toString [
          "${pkgs.vpsf-status}/bin/vpsf-status"
          "${configFile}"
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
