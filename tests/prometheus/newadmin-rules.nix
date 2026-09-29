{ pkgs }:
let
  groups = import ../../modules/clusterconf/monitor/rules/vpsadmin.nix {
    lib = pkgs.lib;
  };
  names = pkgs.lib.concatMap (group: map (rule: rule.alert) group.rules) groups;
  expected = [
    "NewadminBffNotActive"
    "NewadminInfraScrapeMissing"
    "NewadminCertificateExpiring"
    "NewadminFrontendProbeMissing"
    "NewadminBffProbeMissing"
    "NewadminVpsfreeCzWebDown"
    "NewadminBffVpsfreeCzWebDown"
  ];
  ruleFile = pkgs.writeText "newadmin-rules.json" (builtins.toJSON { inherit groups; });
  testFile = pkgs.replaceVars ./newadmin-rules.yml { inherit ruleFile; };
in
assert pkgs.lib.all (name: builtins.elem name names) expected;
pkgs.runCommand "newadmin-prometheus-rules" { nativeBuildInputs = [ pkgs.prometheus.cli ]; } ''
  promtool check rules ${ruleFile}
  promtool test rules ${testFile}
  touch $out
''
