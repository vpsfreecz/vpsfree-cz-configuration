{ lib }:
rec {
  findConfig =
    { config, type, spin, domain, location, name }:
    {
      node = findNode {
        nodes = config.nodes;
        inherit spin domain location name;
      };
    }.${type};

  findNode =
    { nodes, spin, domain, location, name}:
    {
      vpsadminos = findOsNode {
        domains = nodes.vpsadminos;
        inherit domain location name;
      };
    }.${spin};

  findOsNode =
    { domains, domain, location, name }:
    domains.${domain}.${location}.${name};
}
