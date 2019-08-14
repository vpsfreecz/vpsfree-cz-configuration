{ deploymentsExpr }:
let
  deployments = import deploymentsExpr;

  nameValuePairs = builtins.map (d: {
    name = d.fqdn;
    value = {
      inherit (d) type spin name location domain fqdn role;
      config = configByType d.config d.type d.spin;
    };
  }) deployments;

  configByType = config: type: spin: rec {
    base = {
      inherit (config) addresses netboot;
    };

    container = base // { inherit (config) container; };

    node = base // (nodeConfigBySpin config spin);

    machine = base;
  }.${type};

  nodeConfigBySpin = config: spin: rec {
    base = {
      inherit (config) node;
    };

    openvz = base // { inherit (config) vzNode; };

    vpsadminos = base // { inherit (config) osNode; };
  }.${spin};
in {
  deploymentsList = builtins.map (d: d.fqdn) deployments;

  deploymentsInfo = builtins.listToAttrs nameValuePairs;
}
