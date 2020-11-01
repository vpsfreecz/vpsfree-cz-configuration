{ lib }:
{
  sshKeys = import ./ssh-keys.nix;

  vpsadmin = import ./vpsadmin { inherit lib; };
}
