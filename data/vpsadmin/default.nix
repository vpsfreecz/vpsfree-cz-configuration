{ lib }:
{
  containers = import ./containers.nix;

  networks = import ./networks { inherit lib; };
}
