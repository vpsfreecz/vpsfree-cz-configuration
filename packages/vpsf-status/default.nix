{ buildGo117Module, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "ceb9fde3778ec6f7b1c4b90d67d8722a6b125437";
in buildGo117Module rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256:0q10ybjrqmy712fack66zbc39bhknircq27vdrpjl0wchmfnyadz";
  };

  vendorSha256 = "sha256:1is1g69r3xpipcy1pk5dwjxw5ywyk2miqr06smg2hp89slkqswba";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
