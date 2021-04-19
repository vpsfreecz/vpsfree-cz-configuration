{ stdenvNoCC, lib, fetchFromGitHub, bash, smartmontools }:
let
  rev = "80884d276984420c6f358c35b9140f246ecb0946";
  shortRev = builtins.substring 0 7 rev;
in stdenvNoCC.mkDerivation rec {
  pname = "node-exporter-textfile-collector-scripts";
  version = shortRev;

  src = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "node-exporter-textfile-collector-scripts";
    inherit rev;
    sha256 = "sha256:0fn070g3hwclbjfclilcy0146nv0i92sxqaj5gc212nibk609r81";
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
