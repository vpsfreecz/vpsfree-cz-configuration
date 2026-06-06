{
  bundlerEnv,
  fetchFromGitHub,
  lib,
}:
let
  vpsfbot = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsfree-irc-bot";
    rev = "c5b1b4de4bdfd35019240e737fe99e06e068dda9";
    sha256 = "sha256-MJa82CfC1uvtm/+hNVUgh3GiHmgLKq8f35Oho9C+EdI=";
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
