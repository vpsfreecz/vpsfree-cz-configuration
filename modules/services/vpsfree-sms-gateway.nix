{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.vpsfreeSmsGateway;

  configTemplate = pkgs.writeText "vpsfree-sms-gateway-config.json" (
    builtins.toJSON (
      recursiveUpdate cfg.settings {
        listen_address = "${cfg.listenAddress}:${toString cfg.port}";
        database_path = "${cfg.stateDirectory}/gateway.db";
        gateway_name = cfg.gatewayName;
        auth = {
          alertmanager_token = "#alertmanager_token#";
          vpsadmin_token = "#vpsadmin_token#";
          status_token = "#status_token#";
        }
        // optionalAttrs (cfg.callbackTokenFile != null) {
          callback_token = "#callback_token#";
        };
      }
    )
  );

  replaceSecret = placeholder: path: ''
    sed -e "s,#${placeholder}#,$(head -n1 ${path}),g" -i "${cfg.stateDirectory}/config.yml"
  '';
in
{
  options.services.vpsfreeSmsGateway = {
    enable = mkEnableOption "vpsFree.cz SMS gateway";

    package = mkOption {
      type = types.package;
      description = "vpsfree-sms-gateway package to run.";
    };

    user = mkOption {
      type = types.str;
      default = "vpsfree-sms-gateway";
      description = "User under which the SMS gateway runs.";
    };

    group = mkOption {
      type = types.str;
      default = "vpsfree-sms-gateway";
      description = "Group under which the SMS gateway runs.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address on which the SMS gateway listens.";
    };

    port = mkOption {
      type = types.int;
      default = 9876;
      description = "Port on which the SMS gateway listens.";
    };

    stateDirectory = mkOption {
      type = types.str;
      default = "/var/lib/vpsfree-sms-gateway";
      description = "State directory for the SQLite queue and runtime config.";
    };

    gatewayName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Stable gateway name reported in callbacks and metrics.";
    };

    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "SMS gateway settings, excluding auth tokens.";
    };

    alertmanagerTokenFile = mkOption {
      type = types.path;
      description = "File containing the Alertmanager bearer token.";
    };

    vpsadminTokenFile = mkOption {
      type = types.path;
      description = "File containing the vpsAdmin bearer token.";
    };

    statusTokenFile = mkOption {
      type = types.path;
      description = "File containing the status API bearer token.";
    };

    callbackTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Optional legacy bearer token used for vpsAdmin callbacks that were
        queued before per-message HMAC callback signatures were available.
      '';
    };
  };

  config = mkIf cfg.enable {
    users.users = optionalAttrs (cfg.user == "vpsfree-sms-gateway") {
      ${cfg.user} = {
        group = cfg.group;
        home = cfg.stateDirectory;
        isSystemUser = true;
      };
    };

    users.groups = optionalAttrs (cfg.group == "vpsfree-sms-gateway") {
      ${cfg.group} = { };
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDirectory}' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    environment.systemPackages = [ cfg.package ];

    systemd.services.vpsfree-sms-gateway = {
      description = "vpsFree.cz SMS gateway";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = with pkgs; [ coreutils ];
      preStart = ''
        install -d -o ${cfg.user} -g ${cfg.group} -m 0750 "${cfg.stateDirectory}"
        cp -f ${configTemplate} "${cfg.stateDirectory}/config.yml"
        ${replaceSecret "alertmanager_token" cfg.alertmanagerTokenFile}
        ${replaceSecret "vpsadmin_token" cfg.vpsadminTokenFile}
        ${replaceSecret "status_token" cfg.statusTokenFile}
        ${optionalString (cfg.callbackTokenFile != null) (
          replaceSecret "callback_token" cfg.callbackTokenFile
        )}
        chown ${cfg.user}:${cfg.group} "${cfg.stateDirectory}/config.yml"
        chmod 0440 "${cfg.stateDirectory}/config.yml"
      '';
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDirectory;
        ExecStart = "${cfg.package}/bin/vpsfree-sms-gateway -config ${cfg.stateDirectory}/config.yml";
        Restart = "on-failure";
        RestartSec = 30;
      };
    };
  };
}
