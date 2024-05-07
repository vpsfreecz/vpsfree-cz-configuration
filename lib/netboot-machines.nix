{
  cluster,
  tags,
  dynamicTags ? [],
  buildAttribute ? [ "system" "build" "dist" ],
  buildGenerations,
  hostGenerations
}:
let
  machines = import ../cluster/netbootable.nix;

  carried = map (name:
    let
      clusterMachine = cluster.${name};

      alias =
        if isNull clusterMachine.host.location then
          clusterMachine.host.name
        else
          "${clusterMachine.host.location}/${clusterMachine.host.name}";
    in {
      machine = name;

      inherit alias;

      extraModules =
        if clusterMachine.spin == "vpsadminos" then
          [ ../configs/node/pxe-only.nix ]
        else
          [];

      tags = tags ++ (map (t: "${t}#${alias}") dynamicTags);

      inherit buildAttribute buildGenerations hostGenerations;
    }
  ) machines;
in carried