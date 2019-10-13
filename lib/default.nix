{ lib, pkgs }:
with lib;
let
  deployment = import ./deployment { inherit pkgs lib findConfig; };

  reverseDomain = domain: concatStringsSep "." (reverseList (splitString "." domain));

  findConfig =
    { cluster, domain, location, name }:
    let
      realLocation = if isNull location then "global" else location;
    in cluster.${domain}.${realLocation}.${name};

  makeDeployment =
    { domain, location, name, config }:
    with lib;
    let
      attrs = {
        inherit domain name;
        location = if location == "global" then null else location;
        fqdn = reverseDomain (concatStringsSep "." (
          [ domain ]
          ++
          (optional (location != "global") location)
          ++
          [ name ]
        ));
        inherit (config) type spin;
        role = if config.type == "node" then config.node.role else null;
        inherit config;
      };

      toplevel = buildConfig attrs;
    in attrs // { build.toplevel = toplevel; };

  buildConfig =
    { domain, location, name, fqdn, type, spin, role, ... }:
    if type == "node" then
      deployment.osNode { inherit name location domain fqdn role; }
    else if type == "machine" && spin == "vpsadminos" then
      deployment.osMachine { inherit name location domain fqdn; }
    else if type == "machine" && spin == "nixos" then
      deployment.nixosMachine { inherit name location domain fqdn; }
    else if type == "container" && spin == "nixos" then
      deployment.osContainer { inherit name location domain fqdn; }
    else
      null;
in rec {
  mkNetUdevRule = name: mac: ''
  ACTION=="add", SUBSYSTEM=="net", DRIVERS=="?*", KERNEL=="eth*", ATTR{address}=="${mac}", NAME="${name}"
  '';

  mkNetUdevRules = rs: concatStringsSep "\n" (mapAttrsToList (name: mac:
    mkNetUdevRule name mac
  ) rs);

  inherit findConfig;

  # Return all configured deployments in a list
  getClusterDeployments = cluster:
    flatten (mapAttrsToList (domain: locations:
      flatten (mapAttrsToList (location: hosts:
        mapAttrsToList (name: config:
          makeDeployment { inherit domain location name config; }
        ) hosts
      ) locations)
    ) cluster);

  # Return configured deployments in a particular domain in a list
  getDomainDeployments = cluster: domain:
    filter (d: d.domain == domain) (getClusterDeployments cluster);

  # Get deployments with type == node
  getNodes = cluster: domain:
    builtins.filter (d:
      d.domain == domain && d.type == "node"
    ) (getClusterDeployments cluster);

  # Get IP version addresses from all machines in a cluster
  getAllAddressesOf = cluster: v:
    let
      deps = getClusterDeployments cluster;
      addresses = flatten (map (d:
        map (a: d // a) d.config.addresses.${"v${toString v}"}
      ) deps);
    in addresses;
}
