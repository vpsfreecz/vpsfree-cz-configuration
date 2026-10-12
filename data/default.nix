{ lib }:
{
  sshKeys = import ./ssh-keys.nix;

  meet = import ./meet.nix;

  monitoring = import ./monitoring.nix;

  vpsadmin = import ./vpsadmin { inherit lib; };

  cloudflare = import ./cloudflare.nix;
}
