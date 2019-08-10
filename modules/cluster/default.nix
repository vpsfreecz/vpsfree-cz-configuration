{ config, lib, ... }@args:
with lib;
let
  deployment = {
    options = {
      osNode = mkOption {
        type = types.nullOr (types.submodule osNode);
      };
    };
  };

  osNode = (import ./nodes/vpsadminos.nix) args;
in {
  options = {
    cluster = mkOption {
      #      domain         location       name           deployment
      type = types.attrsOf (types.attrsOf (types.attrsOf (types.submodule deployment)));
      default = {};
    };
  };
}
