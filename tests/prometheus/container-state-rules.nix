{ pkgs }:

let
  ruleGroups = import ../../modules/clusterconf/monitor/rules/nodes.nix;
  nodesGroup = builtins.head (builtins.filter (group: group.name == "nodes") ruleGroups);
  expectedAlertNames = [
    "HypervisorEmpty"
    "HypervisorNearlyEmpty"
    "VpsStartingTooLong"
    "VpsAborting"
    "VpsConfigError"
    "VpsRuntimeStateUnknown"
    "VpsFrozen"
  ];
  containerStateRules = builtins.filter (
    rule: builtins.elem (rule.alert or "") expectedAlertNames
  ) nodesGroup.rules;
  ruleFile = pkgs.writeText "container-state-rules.json" (
    builtins.toJSON {
      groups = [
        (nodesGroup // { rules = containerStateRules; })
      ];
    }
  );
  testFile = pkgs.replaceVars ./container-state-rules.yml {
    inherit ruleFile;
  };
in
assert map (rule: rule.alert) containerStateRules == expectedAlertNames;
pkgs.runCommand "container-state-prometheus-rules"
  {
    nativeBuildInputs = [ pkgs.prometheus.cli ];
  }
  ''
    promtool check rules ${ruleFile}
    promtool test rules ${testFile}
    touch $out
  ''
