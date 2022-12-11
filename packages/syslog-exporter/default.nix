{ bundlerEnv, lib }:
bundlerEnv {
  name = "syslog-exporter";
  gemdir = ./.;

  meta = with lib; {
    homepage = "https://github.com/vpsfreecz/syslog-exporter";
    platforms = platforms.linux;
    maintainers = [];
    license = licenses.mit;
  };
}
