{ bundlerEnv, fetchFromGitHub, lib }:
let
  vpsfbot = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsfree-irc-bot";
    rev = "45f9d46cb12b62e5acb449ca538815b70b260978";
    sha256 = "sha256-SUKi3/wX4i0wwbWYMxcgtLkruFVS7sBI2IcU0FyQlNU=";
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
