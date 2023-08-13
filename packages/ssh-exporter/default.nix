{ bundlerEnv, lib }:
bundlerEnv {
  name = "ssh-exporter";
  gemdir = ./.;

  meta = with lib; {
    homepage = "https://github.com/vpsfreecz/ssh-exporter";
    platforms = platforms.linux;
    maintainers = [];
    license = licenses.mit;
  };
}
