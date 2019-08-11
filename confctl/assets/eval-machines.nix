{ deploymentsExpr }:
let
  deployments = import deploymentsExpr;

  nameValuePairs = builtins.map (d: {
    name = d.fqdn;
    value = { inherit (d) type spin name location domain fqdn role; };
  }) deployments;
in {
  deploymentsList = builtins.map (d: d.fqdn) deployments;

  deploymentsInfo = builtins.listToAttrs nameValuePairs;
}
