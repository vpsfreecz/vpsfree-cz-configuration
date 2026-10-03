{ pkgs }:

let
  group = builtins.head (import ../../modules/clusterconf/monitor/rules/nodes.nix);
  ruleFile = pkgs.writeText "infra-monitoring-cpu-rules.json" (
    builtins.toJSON {
      groups = [
        (
          group
          // {
            rules = builtins.filter (
              rule:
              builtins.elem (rule.alert or "") [
                "HypervisorHighCpuLoad"
                "HypervisorHighCpuLoadStaging"
                "HypervisorCritOsCpuLoad"
                "HypervisorCritOsCpuLoadStaging"
              ]
            ) group.rules;
          }
        )
      ];
    }
  );
  testFile = pkgs.replaceVars ./infra-monitoring-rules.yml { inherit ruleFile; };
in
pkgs.runCommand "infra-monitoring-rules"
  {
    nativeBuildInputs = [ pkgs.prometheus.cli ];
  }
  ''
    promtool check rules ${ruleFile}
    promtool test rules ${testFile}
    touch $out
  ''
