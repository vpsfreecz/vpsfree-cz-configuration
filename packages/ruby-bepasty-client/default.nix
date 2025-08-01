{
  pkgs,
  lib,
  bundlerApp,
  defaultGemConfig,
}:

bundlerApp {
  pname = "ruby-bepasty-client";
  gemdir = ./.;
  exes = [ "bepastyrb" ];

  meta = with lib; {
    description = "";
    homepage = "https://github.com/aither64/ruby-bepasty-client";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.unix;
  };
}
