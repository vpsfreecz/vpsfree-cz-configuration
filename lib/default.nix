{ lib }:
with lib;
rec {
  mkNetUdevRule = name: mac: ''
  ACTION=="add", SUBSYSTEM=="net", DRIVERS=="?*", KERNEL=="eth*", ATTR{address}=="${mac}", NAME="${name}"
  '';

  mkNetUdevRules = rs: concatStringsSep "\n" (mapAttrsToList (name: mac:
    mkNetUdevRule name mac
  ) rs);

  findConfig =
    { cluster, type, spin, domain, location, name }:
    {
      node = findNode {
        nodes = cluster.${domain}.nodes;
        inherit spin location name;
      };
    }.${type};

  findNode =
    { nodes, spin, location, name}:
    {
      vpsadminos = findOsNode {
        locations = nodes.vpsadminos;
        inherit location name;
      };
    }.${spin};

  findOsNode =
    { locations, location, name }:
    locations.${location}.${name};
}
