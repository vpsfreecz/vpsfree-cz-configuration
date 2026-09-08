{ pkgs }:

let
  ruleFile = pkgs.writeText "vpsf-status-rules.json" (
    builtins.toJSON {
      groups = import ../../modules/clusterconf/monitor/rules/vpsfree-web.nix;
    }
  );

  testFile = pkgs.replaceVars ./vpsf-status-rules.yml {
    inherit ruleFile;
  };
in
pkgs.runCommand "vpsf-status-prometheus-rules"
  {
    nativeBuildInputs = [ pkgs.prometheus.cli ];
  }
  ''
    promtool check rules ${ruleFile}
    promtool test rules ${testFile}
    touch $out
  ''
