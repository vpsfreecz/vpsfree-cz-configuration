{ networkExpr }:
let
  network = import networkExpr;

  ignore = [ "network" "defaults" "resources" "require" "_file" ];

  machines = builtins.removeAttrs network ignore;
in {
  machineList = builtins.attrNames machines;

  machineInfo = builtins.mapAttrs (k: v: v.info) machines;
}
