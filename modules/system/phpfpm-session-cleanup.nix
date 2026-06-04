{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    concatMap
    listToAttrs
    map
    mkAfter
    mkIf
    mkOption
    nameValuePair
    types
    unique
    ;

  cfg = config.vpsfconf.phpfpmSessionCleanup;
  pools = unique cfg.pools;

  baseDir = "/var/lib/phpfpm";
  sessionDir = pool: "${baseDir}/${pool}/sessions";

  mkPoolTmpfiles =
    pool:
    let
      poolCfg = config.services.phpfpm.pools.${pool};
    in
    [
      (nameValuePair "${baseDir}/${pool}" {
        d = {
          mode = "0750";
          user = poolCfg.user;
          group = poolCfg.group;
        };
      })
      (nameValuePair (sessionDir pool) {
        d = {
          mode = "0750";
          user = poolCfg.user;
          group = poolCfg.group;
        };
        e.age = cfg.maxAge;
      })
    ];
in
{
  options.vpsfconf.phpfpmSessionCleanup = {
    pools = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        PHP-FPM pools whose PHP session directory should be managed by this
        configuration.
      '';
    };

    maxAge = mkOption {
      type = types.str;
      default = "1d";
      description = "Maximum age of PHP session files before tmpfiles cleanup.";
    };

    gcMaxLifetime = mkOption {
      type = types.ints.positive;
      default = 86400;
      description = "PHP session.gc_maxlifetime value for managed pools.";
    };
  };

  config = mkIf (pools != [ ]) {
    services.phpfpm.pools = listToAttrs (
      map (
        pool:
        nameValuePair pool {
          phpOptions = mkAfter ''
            session.save_path = ${sessionDir pool}
            session.gc_probability = 0
            session.gc_maxlifetime = ${toString cfg.gcMaxLifetime}
          '';
        }
      ) pools
    );

    systemd.tmpfiles.settings."30-vpsfree-phpfpm-sessions" = {
      ${baseDir}.d = {
        mode = "0755";
        user = "root";
        group = "root";
      };
    }
    // listToAttrs (concatMap mkPoolTmpfiles pools);
  };
}
