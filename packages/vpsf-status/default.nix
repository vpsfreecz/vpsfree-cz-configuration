{ buildGoModule, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "6cca4e395e90d477c8d50a9993060871d30d1639";
in buildGoModule rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-CafghpJmF5uOgMCZQFZLCmS+x02rNVBFS8KADgt2YIE=";
  };

  vendorHash = "sha256-Kyx9MPCjNVERTeKRfMF8EAAlIoengsPtlbf3SQJfng4=";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
