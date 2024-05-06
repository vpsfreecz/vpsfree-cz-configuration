{
  cluster,
  tags,
  buildAttribute ? [ "system" "build" "dist" ]
}:
let
  machines = import ../cluster/netbootable.nix;

  carried = map (name:
    let
      clusterMachine = cluster.${name};
    in {
      machine = name;
      alias =
        if isNull clusterMachine.host.location then
          "${clusterMachine.host.name}"
        else
          "${clusterMachine.host.location}/${clusterMachine.host.name}";
      extraModules =
        if clusterMachine.spin == "vpsadminos" then
          [ ../configs/node/pxe-only.nix ]
        else
          [];
      inherit buildAttribute tags;
    }
  ) machines;
in carried