{ buildGo117Module, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "635f00ec4ad15807f58c079222e3ca23e790704e";
in buildGo117Module rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-wG6tIs6A2mxIcB/+Z+4AolRjW4snV6+KZdTUody6TbE=";
  };

  vendorSha256 = "sha256:1is1g69r3xpipcy1pk5dwjxw5ywyk2miqr06smg2hp89slkqswba";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
