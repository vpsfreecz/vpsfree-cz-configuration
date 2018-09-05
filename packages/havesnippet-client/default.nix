{ pkgs, lib, bundlerApp }:

bundlerApp {
  pname = "havesnippet-client";
  gemdir = ./.;
  exes = [ "havesnippet" "hs" ];

  meta = with lib; {
    description = "";
    homepage    = https://github.com/aither64/havesnippet-client;
    license     = licenses.mit;
    maintainers = [];
    platforms   = platforms.unix;
  };
}
