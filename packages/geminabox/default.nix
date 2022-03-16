{ bundlerEnv, lib }:
bundlerEnv {
  name = "geminabox";
  gemdir = ./.;

  meta = with lib; {
    homepage = "https://github.com/geminabox/geminabox";
    platforms = platforms.linux;
    maintainers = [];
    license = licenses.mit;
  };
}
