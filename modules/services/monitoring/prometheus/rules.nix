{ config, pkgs, lib, ... }:
with lib;
let
  cfg2 = config.services.prometheus2;

  ruleFile = pkgs.writeText "prometheus-rules" (builtins.toJSON {
    groups = cfg2.ruleConfigs;
  });
in {
  options = {
    services.prometheus2.ruleConfigs = mkOption {
      type = types.listOf types.attrs;
      default = [];
    };
  };

  config = mkIf (cfg2.ruleConfigs != []) {
    services.prometheus2.ruleFiles = [ ruleFile ];
  };
}
