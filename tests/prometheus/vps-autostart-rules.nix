{ pkgs }:

let
  ruleGroups =
    import ../../modules/clusterconf/monitor/rules/nodes.nix
    ++ import ../../modules/clusterconf/monitor/rules/nodectld.nix;

  ruleFile = pkgs.writeText "vps-autostart-rules.json" (
    builtins.toJSON {
      groups = builtins.filter (
        group:
        builtins.elem group.name [
          "nodes"
          "nodectld"
        ]
      ) ruleGroups;
    }
  );

  testFile = pkgs.replaceVars ./vps-autostart-rules.yml {
    inherit ruleFile;
  };
in
pkgs.runCommand "vps-autostart-prometheus-rules"
  {
    nativeBuildInputs = [ pkgs.prometheus.cli ];
  }
  ''
    promtool check rules ${ruleFile}
    promtool test rules ${testFile}
    touch $out
  ''
