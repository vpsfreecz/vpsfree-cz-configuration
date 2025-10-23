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
  ssh-exporter = {
    dependencies = [
      "prometheus-client"
      "puma"
      "rack"
    ];
  };
}
