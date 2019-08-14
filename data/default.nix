{ config, lib, ... }@args:
{
  config = {
    _module.args = {
      data = {
        containers = import ./containers.nix;

        networks = import ./networks { inherit lib; };

        sshKeys = import ./ssh-keys.nix;
      };
    };
  };
}
