{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.vpsfree-irc-bot;

  defaultUser = "vpsfbot";

  instanceModule =
    { config, ... }:
    {
      options = {
        package = mkOption {
          type = types.package;
          default = pkgs.vpsfree-irc-bot;
          description = "Which bot package to use.";
        };

        user = mkOption {
          type = types.str;
          default = defaultUser;
          description = "User under which the bot is run.";
        };

        group = mkOption {
          type = types.str;
          default = defaultUser;
          description = "Group under which the bot is run.";
        };

        settings = mkOption {
          type = types.attrs;
          default = { };
          description = ''
            Configuration options passed to the bot
          '';
        };

        extraConfigFiles = mkOption {
          type = types.listOf types.path;
          default = [ ];
          description = ''
            Paths to additional configuration files

            These files can be used to pass secrets to the bot.
          '';
        };
      };
    };

  mkTmpfilesd =
    instances:
    flatten (
      mapAttrsToList (name: inst: [
        "d '${cfg.stateDir}/${name}' 0750 ${inst.user} ${inst.group} - -"
      ]) instances
    );

  defaultSettings = name: {
    state_dir = "${cfg.stateDir}/${name}";
  };

  mkSettings =
    name: settings:
    pkgs.writeText "vpsfree-irc-bot-${name}.json" (
      builtins.toJSON ((defaultSettings name) // settings)
    );

  mkServices =
    instances:
    mapAttrs' (
      name: inst:
      nameValuePair "vpsfree-irc-bot-${name}" {
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          LANG = "en_US.utf8";
          RACK_ENV = "production";
        };
        serviceConfig = {
          Type = "simple";
          User = inst.user;
          Group = inst.group;
          WorkingDirectory = cfg.stateDir;
          ExecStart = toString (
            [
              "${inst.package}/bin/bundle exec"
              "${inst.package}/vpsfree-irc-bot/bin/vpsfree-irc-bot"
              "--config ${mkSettings name inst.settings}"
            ]
            ++ (map (c: "--config ${c}") inst.extraConfigFiles)
          );
          Restart = "on-failure";
          RestartSec = 30;
        };
      }
    ) instances;

  mkUsers =
    instances:
    if (filterAttrs (name: inst: inst.user == defaultUser) instances) != { } then
      {
        ${defaultUser} = {
          uid = 1000;
          group = defaultUser;
          home = cfg.stateDir;
          isSystemUser = true;
        };
      }
    else
      { };

  mkGroups =
    instances:
    if (filterAttrs (name: inst: inst.group == defaultUser) instances) != { } then
      {
        ${defaultUser} = {
          gid = 1000;
        };
      }
    else
      { };
in
{
  options = {
    services.vpsfree-irc-bot = {
      enable = mkEnableOption "Enable vpsFree IRC Bot";

      stateDir = mkOption {
        type = types.str;
        default = "/var/vpsfbot";
        description = "Top-level state directory";
      };

      instances = mkOption {
        type = types.attrsOf (types.submodule instanceModule);
        default = { };
        description = ''
          Bot instances
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0755 - - - -"
    ]
    ++ (mkTmpfilesd cfg.instances);

    systemd.services = mkServices cfg.instances;

    users.users = mkUsers cfg.instances;

    users.groups = mkGroups cfg.instances;
  };
}
