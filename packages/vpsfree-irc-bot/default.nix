{
  bundlerEnv,
  fetchFromGitHub,
  lib,
}:
let
  vpsfbot = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsfree-irc-bot";
    rev = "48b06b915451a8babfea4c0dabf63b11019a1715";
    sha256 = "sha256-LM+cFZ1OnGV+6FXNqu2WitW5t4zttoqW3K2aZYuL2Bo=";
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
