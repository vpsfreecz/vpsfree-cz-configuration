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
    { cluster, domain, location, name }:
    let
      realLocation = if isNull location then "global" else location;
    in cluster.${domain}.${realLocation}.${name};
}
