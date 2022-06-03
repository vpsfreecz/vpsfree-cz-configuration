{ buildGo117Module, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "a0b1202dbaf7230e353fa802f0c28a9afe129ba3";
in buildGo117Module rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256:1i3f7ygyx7zpfnxwkrwypmr6cvcih3n4v3x79crx03kk4y055s2r";
  };

  vendorSha256 = "sha256:1is1g69r3xpipcy1pk5dwjxw5ywyk2miqr06smg2hp89slkqswba";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
