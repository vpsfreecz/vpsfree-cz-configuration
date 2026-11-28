{ pkgs }:

let
  ruleFile = pkgs.writeText "meet-rules.json" (
    builtins.toJSON {
      groups = import ../../modules/clusterconf/monitor/rules/meet.nix;
    }
  );

  testFile = pkgs.replaceVars ./meet-rules.yml {
    inherit ruleFile;
  };
in
pkgs.runCommand "meet-prometheus-rules"
  {
    nativeBuildInputs = [ pkgs.prometheus.cli ];
  }
  ''
    promtool check rules ${ruleFile}
    promtool test rules ${testFile}
    touch $out
  ''
