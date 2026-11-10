{ pkgs }:

let
  ruleFile = pkgs.writeText "meet-master-rules.json" (
    builtins.toJSON {
      groups = import ../../modules/clusterconf/monitor/rules/meet.nix;
    }
  );

  testFile = pkgs.replaceVars ./meet-master-rules.yml {
    inherit ruleFile;
  };
in
pkgs.runCommand "meet-master-prometheus-rules"
  {
    nativeBuildInputs = [ pkgs.prometheus.cli ];
  }
  ''
    promtool check rules ${ruleFile}
    promtool test rules ${testFile}
    touch $out
  ''
