{
  bundlerEnv,
  fetchFromGitHub,
  lib,
}:
let
  vpsfbot = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsfree-irc-bot";
    rev = "a7393bbe514958ad76ccd5ba86406b0270511297";
    sha256 = "sha256-IZD80aV9Dq8mgPxqqJKA6fpuJ8hQyEoSRyn0uyIny1A=";
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
