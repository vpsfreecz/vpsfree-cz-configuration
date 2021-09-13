{ lib }:
{
  containers = import ./containers.nix;
  management = import ./management.nix;
  ospf = import ./ospf.nix;
}
