{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.geminabox;

  defaultUser = "geminabox";

  nixToRuby =
    v:
    if isString v then
      if hasPrefix ":" v then v else ''"${v}"''
    else if isBool v then
      if v then "true" else "false"
    else if isFloat v then
      toString v
    else if isInt v then
      toString v
    else
      v;

  rackupConfig = pkgs.writeText "geminabox-config.ru" ''
    require 'geminabox'

    use Rack::Session::Pool, expire_after: 900
    use Rack::Protection

    # Settings
    ${concatStringsSep "\n" (mapAttrsToList (k: v: "Geminabox.${k} = ${nixToRuby v}") cfg.settings)}

    ${optionalString cfg.pushBasicAuth.enable ''
      # Push authentication
      AUTH_USERS = {
        ${concatStringsSep "  \n" (
          mapAttrsToList (k: v: ''"${k}" => File.read("${v}").strip,'') cfg.pushBasicAuth.users
        )}
      }

      Geminabox::Server.helpers do
        def protected!
          unless authorized?
            response['WWW-Authenticate'] = %(Basic realm="Geminabox")
            halt 401, "No pushing or deleting without auth.\n"
          end
        end

        def authorized?
          @auth ||= Rack::Auth::Basic::Request.new(request.env)
          return false if !@auth.provided? || !@auth.basic? || !@auth.credentials

          user, pass = @auth.credentials
          AUTH_USERS.has_key?(user) && AUTH_USERS[user] == pass
        end
      end

      Geminabox::Server.before '/upload' do
        protected!
      end

      Geminabox::Server.before do
        protected! if request.delete?
      end

      Geminabox::Server.before '/api/v1/gems' do
        unless env['HTTP_AUTHORIZATION'] == 'API_KEY'
          halt 401, "Access Denied. Api_key invalid or missing.\n"
        end
      end
    ''}

    # Extra config
    ${cfg.extraConfig}

    # Startup
    run Geminabox::Server
  '';

  thinYml = pkgs.writeText "thin.yml" ''
    address: ${cfg.address}
    port: ${toString cfg.port}
    rackup: ${rackupConfig}
    pid: ${cfg.stateDir}/pids/thin.pid
    log: ${cfg.stateDir}/log/thin.log
    environment: production
    tag: geminabox
  '';
in
{
  options = {
    services.geminabox = {
      enable = mkEnableOption "Enable Gem in a Box server";

      package = mkOption {
        type = types.package;
        default = pkgs.geminabox;
        description = "Which geminabox package to use.";
      };

      user = mkOption {
        type = types.str;
        default = defaultUser;
        description = "User under which geminabox is run.";
      };

      group = mkOption {
        type = types.str;
        default = defaultUser;
        description = "Group under which geminabox is run.";
      };

      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address on which geminabox is run.";
      };

      port = mkOption {
        type = types.int;
        default = 8000;
        description = "Port on which geminabox is run.";
      };

      stateDir = mkOption {
        type = types.str;
        default = "/var/geminabox";
        description = "The state directory";
      };

      pushBasicAuth = {
        enable = mkEnableOption "Require HTTP basic auth for gem push";

        users = mkOption {
          type = types.attrs;
          default = { };
          description = "Users allowed push access";
        };
      };

      settings = mkOption {
        type = types.attrs;
        default = { };
        description = ''
          Geminabox settings, see
          https://github.com/geminabox/geminabox/blob/master/lib/geminabox.rb
        '';
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Extra rackup config";
      };
    };
  };

  config = mkIf cfg.enable {
    services.geminabox.settings.data = "${cfg.stateDir}/data";

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0750 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.stateDir}/data' 0750 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.stateDir}/log' 0750 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.stateDir}/pids' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.geminabox = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment.RACK_ENV = "production";
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = "${cfg.stateDir}";
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
      ${cfg.group} = { };
    };
  };
}
