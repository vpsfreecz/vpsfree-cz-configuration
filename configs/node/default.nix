{ config, ... }:
{
  imports = [
    ./base.nix
    ./bird.nix
    ./halt-silence.nix
  ];
}
