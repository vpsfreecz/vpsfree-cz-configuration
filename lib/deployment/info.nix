{ config, lib, type, spin, name, location, domain, fqdn, findConfig, ... }:
{
  inherit type spin name location domain fqdn;
  config = findConfig {
    inherit (config) cluster;
    inherit name location domain;
  };
}
