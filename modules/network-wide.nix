{ lib, config, pkgs, ... }:

with lib;


let
  cfg = config.global;
  domain = cfg.domain;
  pinned = import ../pinned.nix {};

in
{
  options = {
    global = rec {
      domain = mkOption {
        type = types.str;
        description = "Domain of the webserver";
        default = "vpsadminos.org";
      };

      email = mkOption {
        type = types.str;
        description = "Email for this domain to be used in ACME, certs and related";
        default = "devnull@${domain}";
      };
    };
  };

  config = {
  };
}
