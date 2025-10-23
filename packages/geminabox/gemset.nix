{
  builder = {
  };
  compact_index = {
  };
  daemons = {
  };
  eventmachine = {
  };
  faraday = {
    dependencies = [
      "faraday-net_http"
      "json"
      "logger"
    ];
  };
  faraday-net_http = {
    dependencies = [ "net-http" ];
  };
  geminabox = {
    dependencies = [
      "builder"
      "faraday"
      "httpclient"
      "nesty"
      "reentrant_flock"
      "sinatra"
    ];
  };
  httpclient = {
    dependencies = [ "mutex_m" ];
  };
  json = {
  };
  logger = {
  };
  mustermann = {
    dependencies = [ "ruby2_keywords" ];
  };
  mutex_m = {
  };
  nesty = {
  };
  net-http = {
    dependencies = [ "uri" ];
  };
  rack = {
  };
  rack-protection = {
    dependencies = [ "rack" ];
  };
  reentrant_flock = {
  };
  ruby2_keywords = {
  };
  rubygems-generate_index = {
    dependencies = [ "compact_index" ];
  };
  sinatra = {
    dependencies = [
      "mustermann"
      "rack"
      "rack-protection"
      "tilt"
    ];
  };
  thin = {
    dependencies = [
      "daemons"
      "eventmachine"
      "logger"
      "rack"
    ];
  };
  tilt = {
  };
  uri = {
  };
}
