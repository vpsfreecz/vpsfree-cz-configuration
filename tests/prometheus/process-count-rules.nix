{ pkgs }:

let
  ruleGroups =
    import ../../modules/clusterconf/monitor/rules/nodes.nix
    ++ import ../../modules/clusterconf/monitor/rules/infra.nix;

  infraGroup = builtins.head (builtins.filter (group: group.name == "infra") ruleGroups);

  infraProcessRules = builtins.filter (
    rule: builtins.match "Infra.*ProcessCount" (rule.alert or "") != null
  ) infraGroup.rules;

  infraProcessAlertNames = map (rule: rule.alert) infraProcessRules;

  expectedInfraProcessAlertNames = [
    "InfraWarnProcessCount"
    "InfraCritProcessCount"
  ];

  ruleFile = pkgs.writeText "process-count-rules.json" (
    builtins.toJSON {
      groups = builtins.filter (
        group:
        builtins.elem group.name [
          "nodes"
          "infra"
        ]
      ) ruleGroups;
    }
  );

  testFile = pkgs.replaceVars ./process-count-rules.yml {
    inherit ruleFile;
  };
in
assert infraProcessAlertNames == expectedInfraProcessAlertNames;
assert builtins.all (rule: rule.labels.severity != "fatal") infraProcessRules;
pkgs.runCommand "process-count-prometheus-rules"
  {
    nativeBuildInputs = [ pkgs.prometheus.cli ];
  }
  ''
    promtool check rules ${ruleFile}
    promtool test rules ${testFile}
    touch $out
  ''
