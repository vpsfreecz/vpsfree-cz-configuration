{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  geminaboxCfg = config.services.geminabox;

  cfg = geminaboxCfg.garbage-collector;

  gcScript = script: ''
    ${script}
    rc=$?
    [ $rc != 0 ] && echo "Script ${script} failed with exit status $rc" && exit_status=1
  '';

  gcService = pkgs.writeScript "geminabox-gc" ''
    #!${pkgs.bash}/bin/bash
    exit_status=0

    ${concatMapStringsSep "\n\n" gcScript cfg.scripts}

    # Reindex geminabox db
    ${pkgs.curl}/bin/curl "http://localhost:${toString geminaboxCfg.port}/reindex" \
      || exit_status=1 \
      > /dev/null

    exit $exit_status
  '';
in
{
  options = {
    services.geminabox.garbage-collector = {
      enable = mkEnableOption "Enable the gem garbage collector facility";

      scripts = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = ''
          A list of scripts that are called to garbage-collect gems
        '';
      };
    };
  };

  config = mkIf (geminaboxCfg.enable && cfg.enable) {
    systemd.tmpfiles.rules = [
      "d '${geminaboxCfg.stateDir}/gc' 0750 ${geminaboxCfg.user} ${geminaboxCfg.group} - -"
      "d '${geminaboxCfg.stateDir}/trash' 0750 ${geminaboxCfg.user} ${geminaboxCfg.group} - -"
    ];

    systemd.services.geminabox-gc = {
      serviceConfig = {
        Type = "simple";
        User = geminaboxCfg.user;
        Group = geminaboxCfg.group;
        WorkingDirectory = geminaboxCfg.stateDir;
        ExecStart = gcService;
      };
      startAt = "daily";
    };
  };
}
