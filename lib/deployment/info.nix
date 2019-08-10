{ config, lib, type, spin, name, location, domain, fqdn, ... }:
let
  dataLib = import ../../data/lib.nix { inherit lib; };
in {
  inherit type spin name location domain fqdn;
  config = dataLib.findConfig { inherit config type spin name location domain; };
}
