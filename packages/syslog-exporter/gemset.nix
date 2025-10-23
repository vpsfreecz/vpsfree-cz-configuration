{
  base64 = {
  };
  nio4r = {
  };
  prometheus-client = {
    dependencies = [ "base64" ];
  };
  puma = {
    dependencies = [ "nio4r" ];
  };
  rack = {
  };
  syslog-exporter = {
    dependencies = [
      "prometheus-client"
      "puma"
      "rack"
    ];
  };
}
