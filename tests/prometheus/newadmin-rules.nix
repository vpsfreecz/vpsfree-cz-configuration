{ pkgs }:
let
  groups = import ../../modules/clusterconf/monitor/rules/vpsadmin.nix {
    lib = pkgs.lib;
  };
  rules = pkgs.lib.concatMap (group: group.rules) groups;
  newadminRules = pkgs.lib.filter (rule: pkgs.lib.hasPrefix "Newadmin" rule.alert) rules;
  names = map (rule: rule.alert) newadminRules;
  expected = [
    "NewadminBffNotActive"
    "NewadminInfraScrapeMissing"
    "NewadminCertificateExpiring"
    "NewadminFrontendProbeMissing"
    "NewadminBffProbeMissing"
    "NewadminVpsfreeCzExporterDown"
    "NewadminBffVpsfreeCzExporterDown"
    "NewadminVpsfreeCzWebDown"
    "NewadminBffVpsfreeCzWebDown"
  ];
  ruleFile = pkgs.writeText "newadmin-rules.json" (builtins.toJSON { inherit groups; });
  testFile = pkgs.replaceVars ./newadmin-rules.yml { inherit ruleFile; };
in
assert pkgs.lib.all (name: builtins.elem name names) expected;
assert builtins.length newadminRules == builtins.length expected;
assert pkgs.lib.all (rule: rule.labels.severity == "warning") newadminRules;
pkgs.runCommand "newadmin-prometheus-rules" { nativeBuildInputs = [ pkgs.prometheus.cli ]; } ''
  promtool check rules ${ruleFile}
  promtool test rules ${testFile}
  touch $out
''
