{ bundlerEnv, fetchFromGitHub, lib }:
let
  vpsfbot = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsfree-irc-bot";
    rev = "a6ae4405a3cbfc9a9c63e8697668d729503e67fd";
    sha256 = "sha256:0xs1cwbyjr26rjn329xzkw0y80861y8z79hf4ig07mvszb6637fx";
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
