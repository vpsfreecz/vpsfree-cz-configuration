{ buildGoModule, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "996ea43f50bce3da4ae9508d019cfaa5b5ecaebb";
in buildGoModule rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-ARtzKmYTEShBYAldF9KDw8zhXUOFQzmxBvsjvLyxeS0=";
  };

  vendorHash = "sha256-Kyx9MPCjNVERTeKRfMF8EAAlIoengsPtlbf3SQJfng4=";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
