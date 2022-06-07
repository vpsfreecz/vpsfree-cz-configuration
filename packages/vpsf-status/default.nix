{ buildGo117Module, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "634547790c4e2a70fa2d0aeec6ca61a6d71d7cf4";
in buildGo117Module rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256:0jhggilrzgl26zpy9jhdk2ir4c7rwydnvlwcqj83cdnlhnp96bn3";
  };

  vendorSha256 = "sha256:1is1g69r3xpipcy1pk5dwjxw5ywyk2miqr06smg2hp89slkqswba";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
