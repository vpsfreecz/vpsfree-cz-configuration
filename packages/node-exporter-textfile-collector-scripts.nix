{ stdenvNoCC, lib, fetchFromGitHub, bash, smartmontools }:
let
  rev = "414fb44693444cb96a55c7152cdd84d531888e1f";
  shortRev = builtins.substring 0 7 rev;
in stdenvNoCC.mkDerivation rec {
  pname = "node-exporter-textfile-collector-scripts";
  version = shortRev;

  src = fetchFromGitHub {
    owner = "prometheus-community";
    repo = "node-exporter-textfile-collector-scripts";
    inherit rev;
    sha256 = "sha256:13ja3l78bb47xhdfsmsim5sqggb9avg3x872jqah1m7jm9my7m98";
  };

  buildInputs = [
    bash
    smartmontools
  ];

  patchPhase = ''
    patchShebangs *.sh

    substituteInPlace ./smartmon.sh \
      --replace /usr/sbin/smartctl ${smartmontools}/bin/smartctl
  '';

  dontBuild = true;

  installPhase = ''
    install -Dm755 -t $out/bin smartmon.sh
  '';

  meta = with lib; {
    description = "Scripts for node-exporter's textfile collector";
    homepage = "https://github.com/prometheus-community/node-exporter-textfile-collector-scripts";
    license = licenses.asl20;
    platforms = platforms.all;
    maintainers = with maintainers; [];
  };
}
