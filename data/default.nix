{ config, lib, ... }@args:
{
  imports = (import ./modules/module-list.nix) ++ (import ./configs/config-list.nix);

  config = {
    _module.args = {
      data = {
        networks = import ./networks { inherit lib; };

        lib = import ./lib.nix { inherit lib; };
      };
    };
  };
}
