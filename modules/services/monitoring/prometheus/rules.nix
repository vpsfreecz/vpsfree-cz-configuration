{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.prometheus;

  ruleFile = pkgs.writeText "prometheus-rules" (builtins.toJSON {
    groups = cfg.ruleConfigs;
  });
in {
  options = {
    services.prometheus.ruleConfigs = mkOption {
      type = types.listOf types.attrs;
      default = [];
    };
  };

  config = mkIf (cfg.ruleConfigs != []) {
    services.prometheus.ruleFiles = [ ruleFile ];
  };
}
