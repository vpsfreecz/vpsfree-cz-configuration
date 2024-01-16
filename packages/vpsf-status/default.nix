{ buildGoModule, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "61b1efedcd17b0fafef1541bd9ed20d720305a95";
in buildGoModule rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-WaqXgqKqzZRP8ueRBCeECn2T23w/1GweZzYijE21h5U=";
  };

  vendorHash = "sha256-m38yOdn+W0sL5tCK6i+a683UaQF5DeR0w49GW0qyq6k=";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
