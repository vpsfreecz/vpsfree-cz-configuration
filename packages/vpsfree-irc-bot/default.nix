{ bundlerEnv, fetchFromGitHub, lib }:
let
  vpsfbot = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsfree-irc-bot";
    rev = "f6f349c85961832c768cf00fde736fc35f354ea1";
    sha256 = "sha256-J77qsJ4bR4EPedd9GordJxGaUxCn+coIRaU7Q/0I6kE=";
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
