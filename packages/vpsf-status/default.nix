{ buildGoModule, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "f3d87a49ea58810b9dbb7ce2a54d30f2fe743a7d";
in buildGoModule rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-p7QVWJjIJAfwBodNRmLitvJG6R9yae1sswBI3kmHiM0=";
  };

  vendorHash = "sha256-Kyx9MPCjNVERTeKRfMF8EAAlIoengsPtlbf3SQJfng4=";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
