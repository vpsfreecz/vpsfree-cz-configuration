{ stdenvNoCC, lib, fetchFromGitHub, bash, smartmontools }:
let
  rev = "fd6ed02e26c11995386d1f7a9db75025fae85de9";
  shortRev = builtins.substring 0 7 rev;
in stdenvNoCC.mkDerivation rec {
  pname = "node-exporter-textfile-collector-scripts";
  version = shortRev;

  src = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "node-exporter-textfile-collector-scripts";
    inherit rev;
    sha256 = "sha256:1pr2sjfm01hwv1np6sshm9djnk8nwxzvrylan8ljmrfpgjyqpz2n";
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
