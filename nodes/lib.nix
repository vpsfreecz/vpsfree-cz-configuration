{ lib }:

with lib;

rec {
  mkNetUdevRule = name: mac: ''
  ACTION=="add", SUBSYSTEM=="net", DRIVERS=="?*", KERNEL=="eth*", ATTR{address}=="${mac}", NAME="${name}"
  '';

  mkNetUdevRules = rs: concatStringsSep "\n" (mapAttrsToList (name: mac: mkNetUdevRule name mac) rs);
}
