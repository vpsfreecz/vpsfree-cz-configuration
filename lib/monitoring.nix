{ lib }:
{
  managementFqdn =
    hostname:
    let
      parts = lib.splitString "." hostname;
    in
    lib.concatStringsSep "." ([ "${builtins.head parts}-mgmt" ] ++ builtins.tail parts);
}
