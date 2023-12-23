{ bundlerEnv, fetchFromGitHub, lib }:
let
  vpsfbot = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsfree-irc-bot";
    rev = "23bee4d566e0c353f6eb373c0dab6765e9df8a31";
    sha256 = "sha256-qwoRXk/HjztZ9hO/x2j1/U8Qnk6vkzsncbtwjegWX9c=";
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
