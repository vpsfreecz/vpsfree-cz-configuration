{ buildGoModule, fetchFromGitHub, lib }:
let
  owner = "vpsfreecz";
  repo = "vpsf-status";
  rev = "258621d15734fd9edf6b3502966a4e671b5481a4";
in buildGoModule rec {
  name = "vpsf-status-${version}";
  version = lib.substring 0 7 rev;

  src = fetchFromGitHub {
    inherit owner repo rev;
    sha256 = "sha256-7eTQLefiuHE0NWBs0KEkGBB9xthpDFP73/qwcTLPmNQ=";
  };

  vendorHash = "sha256-A6qHt0GeNXHsUQ2NF5JIQ3O8bvCi6JTwMOfC8TL07PY=";

  postInstall = ''
    mkdir -p $out/share/vpsf-status
    cp -r public templates $out/share/vpsf-status/
  '';
}
