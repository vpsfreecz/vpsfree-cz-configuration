{
  bundlerEnv,
  fetchFromGitHub,
  lib,
}:
let
  vpsfbot = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsfree-irc-bot";
    rev = "e9c60b0b95d3cc0dad6f012d8127c2bc078cfa7d";
    sha256 = "sha256-jONz5RyWIzH2/h9oALb31Ms1pQlbwP3MNRUe1vwzp5A=";
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
