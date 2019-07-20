{ deploymentsExpr }:
let
  deployments = import deploymentsExpr;
in {
  deploymentsList = builtins.attrNames deployments;

  deploymentsInfo = builtins.mapAttrs (k: v: {
    inherit (v) type name location domain fqdn;
  }) deployments;
}
