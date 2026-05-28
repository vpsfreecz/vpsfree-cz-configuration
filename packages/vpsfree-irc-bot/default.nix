{
  bundlerEnv,
  fetchFromGitHub,
  lib,
}:
let
  vpsfbot = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsfree-irc-bot";
    rev = "c6913e184993de4cbbdc7039ac56ba528c050e98";
    sha256 = "sha256-9eCDRp1PDu+3o5JVtqKcRSPQ467/KYtkdWtMdRgi1fw=";
  };
in
bundlerEnv {
  name = "vpsfree-irc-bot";
  gemdir = vpsfbot;
  postBuild = ''
    ln -s ${vpsfbot} $out/vpsfree-irc-bot
  '';

  meta = with lib; {
    homepage = "https://github.com/vpsfreecz/vpsfree-irc-bot";
    platforms = platforms.linux;
    maintainers = [ ];
    license = licenses.mit;
  };
}
