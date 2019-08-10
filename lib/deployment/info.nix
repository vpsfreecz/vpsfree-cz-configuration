{ config, lib, type, spin, name, location, domain, fqdn, ... }:
let
  confLib = import ../. { inherit lib; };
in {
  inherit type spin name location domain fqdn;
  config = confLib.findConfig {
    inherit (config) cluster;
    inherit type spin name location domain;
  };
}
