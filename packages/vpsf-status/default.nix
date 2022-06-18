{ buildGo117Module, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "bd3d2f2372f2f2f579b5f6c701635ddf35c2556c";
in buildGo117Module rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-OUtgXowi2xcbbBSNs71Gg/YcKjgiYuUjeIO8qRU4CaY=";
  };

  vendorSha256 = "sha256:1is1g69r3xpipcy1pk5dwjxw5ywyk2miqr06smg2hp89slkqswba";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
