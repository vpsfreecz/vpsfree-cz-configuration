{ bundlerEnv, fetchFromGitHub, lib }:
let
  vpsfbot = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsfree-irc-bot";
    rev = "2b54fd22c31b0f6e8a61061879e7cf169c0c0a15";
    sha256 = "sha256-1qrX1nj7M5aari2mqQb82+kZzQLC3DgGQ6OfPVnvYRQ=";
  };
in bundlerEnv {
  name = "vpsfree-irc-bot";
  gemdir = vpsfbot;
  postBuild = ''
    ln -s ${vpsfbot} $out/vpsfree-irc-bot
  '';

  meta = with lib; {
    homepage = "https://github.com/vpsfreecz/vpsfree-irc-bot";
    platforms = platforms.linux;
    maintainers = [];
    license = licenses.mit;
  };
}
