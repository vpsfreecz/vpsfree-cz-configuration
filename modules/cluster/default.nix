{ config, lib, ... }@args:
with lib;
let
  domain = {
    options = {
      nodes.vpsadminos = mkOption {
        #      location       name           config
        type = types.attrsOf (types.attrsOf (types.submodule osNode));
      };
    };
  };

  osNode = (import ./nodes/vpsadminos.nix) args;
in {
  options = {
    cluster = mkOption {
      type = types.attrsOf (types.submodule domain);
      default = {};
    };
  };
}
