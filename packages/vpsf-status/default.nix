{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "f57270a3c70e02e2769a5556215d08204df9b9b8";
in
buildGoModule rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-bBKFz+VeGzlVxawrl3ebTqHxmsv/XlZN8rRJoZy3tlA=";
  };

  vendorHash = "sha256-pBrnESZ8QhEoIQ8cq8Z+k1yMW/OVmPwg7eEofgPaOM0=";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
